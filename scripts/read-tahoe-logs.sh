#!/bin/zsh
# Run from Sequoia with the "MACOS TAHOE - Data" volume mounted. Assembles a .logarchive view of Tahoe's
# log store and prints the en0 timeline: boots, link changes, DHCP restarts, router ARP failures.
# Usage: scripts/read-tahoe-logs.sh ["YYYY-MM-DD HH:MM:SS" [end]]     default start = yesterday 00:00
set -u
START="${1:-$(date -v-1d '+%F 00:00:00')}"; END="${2:-}"
DATA="/Volumes/MACOS TAHOE - Data/private/var/db"
[ -d "$DATA/diagnostics" ] || { echo "Tahoe data volume not mounted at $DATA"; exit 1; }
W=$(mktemp -d /tmp/tahoe-logs.XXXXXX); L="$W/tahoe.logarchive"; mkdir -p "$L"
for d in Persist Special Signpost HighVolume timesync Extra; do [ -e "$DATA/diagnostics/$d" ] && ln -s "$DATA/diagnostics/$d" "$L/$d"; done
for d in "$DATA"/uuidtext/*; do ln -s "$d" "$L/$(basename "$d")"; done
printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict><key>OSArchiveVersion</key><integer>4</integer></dict></plist>\n' > "$L/Info.plist"
ENDARG=(); [ -n "$END" ] && ENDARG=(--end "$END")
OUT=~/Desktop/tahoe-en0-$(date +%Y%m%d-%H%M).txt
/usr/bin/log show --archive "$L" --start "$START" "${ENDARG[@]}" --style compact \
  --predicate '(process == "configd" AND eventMessage CONTAINS "en0") OR (process == "kernel" AND (eventMessage CONTAINS "en0: attached" OR eventMessage CONTAINS[c] "AppleIGB" OR eventMessage CONTAINS "PCIe link"))' 2>/dev/null \
  | grep -E 'en0: attached|link status|link ACTIVE|link INACTIVE|router ARP|BOUND|INIT-REBOOT \([0-9.]+\) waiting at 0|AppleIGB|PCIe link' \
  | sed -E 's/^([0-9-]+ [0-9:]+)\.[0-9]+ +[A-Za-z]+ +([a-z_]+)\[[^]]*\] *(\[[^]]*\] )?/\1 \2 /' | cut -c1-160 | awk '!seen[$0]++' > "$OUT"
echo "Timeline -> $OUT ($(wc -l < "$OUT" | tr -d ' ') lines); router ARP failures: $(grep -c 'router ARP failure' "$OUT")"
echo "per hour (boots = 'en0: attached', failures = 'router ARP failure'):"
grep -E 'en0: attached|router ARP failure' "$OUT" | awk '{print substr($0,1,13), ($0 ~ /attached/ ? "boot" : "arp-failure")}' | sort | uniq -c
rm -rf "$W"
