#!/bin/zsh
# Back up the whole EFI of disk0s1 to ~/Desktop/EFI-backup-<date>/ and then remove what no longer
# belongs there: AppleIGB-Tahoe-5.11.*.kext.bak (keeps 5.12.0.kext.bak as the fallback) and the
# OpenCore debug logs opencore-*.txt in the EFI root. config.plist is NOT changed by this script.
# Mount first (you type the password):  sudo diskutil mount disk0s1
set -euo pipefail
EFI=$(mount | sed -n 's|^/dev/disk0s1 on \(.*\) (msdos.*|\1|p')
[ -n "$EFI" ] || { echo "The EFI of disk0s1 is not mounted. Run: sudo diskutil mount disk0s1"; exit 1; }
B=~/Desktop/EFI-backup-$(date +%Y%m%d-%H%M)
mkdir -p "$B"
rsync -a --exclude '.Trashes' --exclude '.fseventsd' --exclude '.Spotlight-V100' "$EFI/" "$B/"
echo "backup: $B ($(du -sh "$B" | cut -f1), $(find "$B" -type f | wc -l | tr -d ' ') files)"
diff -rq --exclude '.Trashes' --exclude '.fseventsd' --exclude '.Spotlight-V100' "$EFI" "$B" && echo "backup verified identical"
echo "free before: $(df -k "$EFI" | awk 'NR==2{print $4}') KB"
for k in "$EFI"/EFI/OC/AppleIGB-Tahoe-5.11.*.kext.bak; do [ -d "$k" ] && { echo "remove $(basename "$k")"; rm -rf "$k"; }; done
n=$(ls "$EFI"/opencore-*.txt 2>/dev/null | wc -l | tr -d ' '); [ "$n" != "0" ] && { echo "remove $n opencore-*.txt logs"; rm -f "$EFI"/opencore-*.txt; }
find "$EFI/EFI" -name '._*' -delete 2>/dev/null || true
echo "kept: $(ls "$EFI/EFI/OC" | grep -E 'kext.bak|config.plist.bak' | tr '\n' ' ')"
echo "free after: $(df -k "$EFI" | awk 'NR==2{print $4}') KB"
sync
diskutil unmount "$EFI" && echo "EFI unmounted"
