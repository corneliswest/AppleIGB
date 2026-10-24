#!/bin/zsh
# Install a built kext as the Tahoe kext (AppleIGB-Tahoe.kext) on the OpenCore EFI of the 2 TB (disk0s1).
# Only the kext bundle is replaced; config.plist is not touched. The previous kext is kept as
# EFI/OC/AppleIGB-Tahoe-<oldversion>.kext.bak (outside Kexts, so OpenCore ignores it).
# Mount first (you type the password):  sudo diskutil mount disk0s1
# Usage: scripts/install-efi.sh dist/AppleIGB-5.12.0.kext
set -euo pipefail
K="${1:?usage: install-efi.sh <kext>}"
[ -f "$K/Contents/MacOS/AppleIGB" ] || { echo "not a kext: $K"; exit 1; }
EFI=$(mount | sed -n 's|^/dev/disk0s1 on \(.*\) (msdos.*|\1|p')
[ -n "$EFI" ] || { echo "The EFI of disk0s1 is not mounted. Run: sudo diskutil mount disk0s1"; exit 1; }
OC="$EFI/EFI/OC"; CFG="$OC/config.plist"; DST="$OC/Kexts/AppleIGB-Tahoe.kext"
[ -f "$CFG" ] || { echo "no config.plist at $CFG"; exit 1; }
[ -d "$DST" ] || { echo "no $DST on the EFI"; exit 1; }
plutil -convert json -o - "$CFG" | python3 -I -c '
import json, sys
j = json.load(sys.stdin)
e = [k for k in j["Kernel"]["Add"] if k.get("BundlePath") == "AppleIGB-Tahoe.kext"]
assert len(e) == 1 and e[0].get("Enabled") and e[0].get("MinKernel") == "25.0.0", e
print("config entry OK:", e[0].get("Comment", ""), "| MinKernel", e[0]["MinKernel"])'
OLDV=$(plutil -extract CFBundleVersion raw -o - "$DST/Contents/Info.plist")
NEWV=$(plutil -extract CFBundleVersion raw -o - "$K/Contents/Info.plist")
echo "installed $OLDV -> new $NEWV   (EFI free: $(df -k "$EFI" | awk 'NR==2{print $4}') KB)"
BAK="$OC/AppleIGB-Tahoe-$OLDV.kext.bak"
[ -e "$BAK" ] && { echo "backup $BAK exists already; remove or rename it first"; exit 1; }
cp -RX "$DST" "$BAK"
rm -rf "$DST"
cp -RX "$K" "$DST"
find "$DST" "$BAK" -name '._*' -delete 2>/dev/null || true
A=$(shasum -a 256 "$DST/Contents/MacOS/AppleIGB" | cut -d' ' -f1); B=$(shasum -a 256 "$K/Contents/MacOS/AppleIGB" | cut -d' ' -f1)
[ "$A" = "$B" ] || { echo "SHA-256 MISMATCH after copy: $A vs $B"; exit 1; }
plutil -lint "$DST/Contents/Info.plist"
echo "installed SHA-256 $A  == build"
echo "backup: $BAK"
sync
diskutil unmount "$EFI" && echo "EFI unmounted"
