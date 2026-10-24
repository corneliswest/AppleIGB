#!/bin/zsh
# Run on Tahoe right after a stall. Saves the kernel message buffer (the only place where the
# AppleIGB IOLog lines are readable) and an ioreg snapshot of the driver. Asks for your password.
L=~/Desktop/igb-dmesg-$(date +%Y%m%d-%H%M).txt
S=~/Desktop/igb-snapshot-$(date +%Y%m%d-%H%M).txt
ioreg -r -c AppleIGB -l > "$S" 2>/dev/null
echo "Kernel buffer -> $L (type your password if asked)"
sudo dmesg > "$L" 2>&1 && grep -i -E 'igb|AppleIGB|en0' "$L" | tail -40
echo "Klaar: $L and $S"
