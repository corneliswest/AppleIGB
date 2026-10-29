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
| 10 | 5.12.2 | **wired TX/RX buffer arrays** (`vzalloc` was `IOMallocPageable`) | **clean**: ~35 h over three boots (2026-10-27 15:47 to 10-28 12:00, 12:00 to 22:56, 22:56 onwards; both restarts were deliberate, shutdown cause 5), swap in use the whole time (1.2 GB of 2 GB at the check), no panic; at 3.6 h into the third boot 14 M packets (9.5 M RX / 4.5 M TX IPv6), 4 M interrupts, all error counters 0, no reinit. 5.12.1 panicked within 1.3 to 2.9 h on three of four boots under the same load |
| 9 | 5.12.1 | accounting fixes on top of 5.12.0: no TX stall/wake events in the ring, monotonic Ierrs/Oerrs, queued RX delivery so Ipkts counts | **clean**: recorder 01:08-02:08 (3326 samples, 3 v4 / 2 v6 single misses, IPv4-heavy: 483 k of 858 k RX packets), then 10.5 h of use with 44 sleep/wake cycles until 12:34, 0 router ARP failures, all error counters 0; Oerrs sane (9); Ipkts still 0 (IONetworkInterface passes the counts to ifnet_input_extended, so the cause is in the kernel accounting, not the driver) |
| 8 | 5.12.0 | **MSI interrupts** (was legacy INTx), event ring, latent RX/TX fixes | **clean**: 60 min (2026-10-24 23:16 to 00:16), MSI active, 1.53 M interrupts, 3.9 M RX / 1.36 M TX packets, 2 sleep/wake cycles, 0 router ARP failures in the Tahoe log, all error counters 0; only isolated 1-s ping misses under load |

## 5.12.2 (test 10)
- Fix: kernel panic in `AppleIGB::outputPacket` (+0x112, `first->skb = skb`), three times on 2026-10-27 (02:50, 11:25, 12:50) with 5.12.1, each while sending IPv6 TCP under memory pressure (3 swapfiles). A fourth 5.12.1 panic at 15:47 (uptime 2.9 h, 5.12.2 already on the EFI but not yet booted) hit `+0x170`, `first->tx_flags = tx_flags`, at `tx_buffer_info + 0xaa*48 + 0x2c`: that entry straddles a page boundary, the `skb` write landed in the resident page and the `tx_flags` write in the paged-out one (CR2 `...f00c`, base `...d000`). The panic header showed `PL: 1, VF: 5`: a page fault with preemption disabled, which `vm_fault_internal` answers with KERN_FAILURE (xnu `osfmk/vm/vm_fault.c`). Cause: the port implemented Linux `vzalloc` with `IOMallocPageable`, so `tx_ring->tx_buffer_info` and `rx_ring->rx_buffer_info` were pageable, and once a page had been swapped out the write under `txLock` (IOSimpleLock) could not be serviced. Linux vmalloc memory is wired; `vzalloc`/`vfree` now use `IOMalloc`/`IOFree`. The arrays are 12 KB (TX, 256 x 48 B) and 4 KB (RX) per ring, so the wired footprint is negligible.
- The fault addresses were page-aligned bases plus `next_to_use * 48 + 0x10`, i.e. valid indexes into an array whose pages were no longer resident; error code 0x3 in the 12:50 panic (page present, write-protected) is the read-only mapping left by the earlier read in `igb_clean_tx_irq`, which runs without the lock.
- Not related: the 2026-10-21 panic (5.11.4, `outputPacket + 0x2bb`, PL 0, read fault, 3.5 min uptime) is the older IPv6 header walk fixed upstream in 5.11.7.

## 5.12.1 (test 9)
- Event ring: TX_STALL/TX_WAKE are no longer recorded as events (they flooded the 128-entry ring under TX saturation); the `tx_stall`/`tx_wake` counters remain.
- Interface error counters: `inputErrors`/`outputErrors` are now computed once per second as sums of monotonic hardware and driver counters (`igb_update_stats`); the packet paths no longer write them, and an output-queue stall is no longer counted as an error. This stops `netstat` from showing Oerrs as multiples of 2^32 (IONetworkInterface treats any decrease as a 32-bit wrap).
- RX delivery: packets are queued with `kInputOptionQueuePacket` and handed to the stack once per poll with `flushInputQueue()` (the pattern IntelMausi and AppleIGC use). With immediate delivery the family never accounted input packets, so `netstat` Ipkts/Ibytes stayed 0. This is the only change in 5.12.1 that touches the data path.

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

### EFI housekeeping (2026-10-25)
- Full EFI backup in `~/Desktop/EFI-backup-20261025-1328` (70 MB, 328 files, verified with diff).
- Removed `AppleIGB-Tahoe-5.11.{8,40,41,42,43}.kext.bak` and 111 `opencore-*.txt` debug logs; kept `AppleIGB-Tahoe-5.12.0.kext.bak` and the config.plist backups. Free space 25 MB -> 55 MB.
- Still open: `Misc -> Debug -> Target` is 67 (writes a 256 KB log per boot); set it to 3 together with the stale kext comment, with a config.plist backup and ocvalidate.
