#!/bin/zsh
# AppleIGB recorder (run on Tahoe, double-click). Every 2 s: IPv4 ping to the router, IPv6 ping,
# ARP state of the router, en0 packet/byte counters and the kext's AppleIGB-DBG counters.
# The AppleIGB-Events ring is logged every 30 s and whenever a ping fails.
# Output: ~/Desktop/igb-rec-<date>.txt. Runs 60 minutes (argument = seconds) or until Ctrl-C.
DUR=${1:-3600}
L=~/Desktop/igb-rec-$(date +%Y%m%d-%H%M).txt
R=$(route -n get default 2>/dev/null | awk '/gateway/{print $2}')
VER=$(kmutil showloaded 2>/dev/null | grep -o 'AppleIGB ([0-9.]*)')
{
  echo "# start $(date '+%F %T') macOS $(sw_vers -productVersion) $VER router=$R"
  echo "# boot-args: $(nvram boot-args 2>/dev/null | cut -f2-)"
  ioreg -r -c AppleIGB -l 2>/dev/null | grep -E '"(AppleIGB-DBG|AppleIGB-Events|IOInterruptSpecifiers)"' | cut -c1-3000
} | tee "$L"
end=$(( $(date +%s) + DUR )); n=0
while [ $(date +%s) -lt $end ]; do
  n=$((n+1))
  p4=FAIL; ping -c1 -t1 "$R" >/dev/null 2>&1 && p4=ok
  p6=FAIL; ping6 -c1 -i1 2606:4700:4700::1111 >/dev/null 2>&1 && p6=ok
  arpst=$(arp -n "$R" 2>/dev/null | awk '{print $4}')
  cnt=$(netstat -I en0 -b 2>/dev/null | awk 'NR==2{printf "ipkts=%s ierrs=%s ibytes=%s opkts=%s oerrs=%s obytes=%s",$5,$6,$7,$8,$9,$10}')
  dbg=$(ioreg -r -c AppleIGB -l 2>/dev/null | grep '"AppleIGB-DBG"' | sed 's/.*"AppleIGB-DBG" = //')
  echo "$(date '+%T') v4=$p4 v6=$p6 arp=$arpst $cnt $dbg" >> "$L"
  echo "$(date '+%T') v4=$p4 v6=$p6 arp=$arpst $cnt"
  if [ $((n % 15)) -eq 0 ] || [ "$p4$p6" != "okok" ]; then
    ioreg -r -c AppleIGB -l 2>/dev/null | grep '"AppleIGB-Events"' | sed "s/.*\"AppleIGB-Events\" = /$(date '+%T') EVENTS /" >> "$L"
  fi
  sleep 1
done
echo "# end $(date '+%F %T')" | tee -a "$L"
echo "Klaar: $L"
