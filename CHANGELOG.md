# AppleIGB (own build) — changelog and test ladder

Target: Intel I211-AT (8086:1539) on Gigabyte X570 Aorus Pro, macOS Tahoe 26.7.1, OpenCore 1.0.8.
Bundle id stays `com.amdosx.driver.AppleIGB`; installed on the EFI as `AppleIGB-Tahoe.kext` (MinKernel 25.0.0).

| Test | Build | Change under test | Result |
|---|---|---|---|
| 3 | ayushere 5.11.8 | upstream Tahoe fixes | LAN gone after ~4 min |
| 4 | 5.11.40 | donatengit + IPv6 fix, MBUF_WAITOK | no RX at all |
| 5 | 5.11.41 | + MBUF_DONTWAIT | IPv4 stalls after ~3 min |
| 6 | 5.11.42 | + IOLog counters | dropouts after 2.5 min; logs undecodable |
| 7 | 5.11.43 | + IORegistry counters | clean 10 min; stalled again on Oct 24 (3x) |
| 8 | 5.12.0 | **MSI interrupts** (was legacy INTx), event ring, latent RX/TX fixes | **clean**: 60 min (2026-10-24 23:16 to 00:16), MSI active, 1.53 M interrupts, 3.9 M RX / 1.36 M TX packets, 2 sleep/wake cycles, 0 router ARP failures in the Tahoe log, all error counters 0; only isolated 1-s ping misses under load |

## 5.12.0 (test 8)
- Interrupts: use the PCI message-signalled (MSI) vector instead of the legacy INTx line; boot-arg `igb-intx=1` forces the old behaviour for A/B tests. The `INT_ASSERTED` gate only applies in INTx mode.
- Interrupt handler always services RX/TX (`igb_poll`) and then handles link-change bits, instead of skipping packet work on link interrupts.
- Diagnostics in the IORegistry: `AppleIGB-DBG` (counters: interrupts, polls, watchdog ticks, per-ethertype RX/TX, drops, checksum status, hardware MAC stats, ring state) and `AppleIGB-Events` (last 64 events with wall-clock time). Read with `ioreg -r -c AppleIGB -l`.
- RX: a failed `mbuf_copyback` now discards the rest of that frame through EOP and hands the DMA page back to the ring (previously: NULL page left in the ring, leak, later NULL dereference). `allocatePacket()` NULL is handled.
- TX: on `igb_tx_map` failure the buffer slot is cleared so the mbuf is not freed twice later.
- Build: `./build.sh 5.12.0`; x86_64 only; Xcode 26.6 / macOS 26.5 SDK.

### Test 8 observations (2026-10-25)
- Passed, but the stall was intermittent before (test 7 was also clean for 5.5 h), so acceptance still needs: two more clean recorder runs, one of them with an IPv4-heavy download (GitHub release), plus 2 days of daily use.
- Heavy traffic in test 8 went over IPv6 (3.85 M of 3.9 M RX packets); IPv4 under load is still untested.
- Cosmetic issues to fix in 5.12.1 (no behaviour change): the `AppleIGB-Events` ring is flooded by TX_STALL/TX_WAKE pairs under TX saturation (keep the counters, drop the events); `netstat` shows Oerrs as multiples of 2^32 because `igb_update_stats` overwrites `outputErrors` with a smaller value each second (IONetworkInterface treats the decrease as a 32-bit wrap); Ipkts/Ibytes stay 0 because `inputPackets` is never reported.
- Optional A/B later: boot once with `igb-intx=1` in boot-args to confirm the stall returns on the legacy interrupt line.
