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
| 8 | 5.12.0 | **MSI interrupts** (was legacy INTx), event ring, latent RX/TX fixes | installed on the EFI 2026-10-24 23:1x (SHA-256 b7085a93…); backup `EFI/OC/AppleIGB-Tahoe-5.11.43.kext.bak`; result pending |

## 5.12.0 (test 8)
- Interrupts: use the PCI message-signalled (MSI) vector instead of the legacy INTx line; boot-arg `igb-intx=1` forces the old behaviour for A/B tests. The `INT_ASSERTED` gate only applies in INTx mode.
- Interrupt handler always services RX/TX (`igb_poll`) and then handles link-change bits, instead of skipping packet work on link interrupts.
- Diagnostics in the IORegistry: `AppleIGB-DBG` (counters: interrupts, polls, watchdog ticks, per-ethertype RX/TX, drops, checksum status, hardware MAC stats, ring state) and `AppleIGB-Events` (last 64 events with wall-clock time). Read with `ioreg -r -c AppleIGB -l`.
- RX: a failed `mbuf_copyback` now discards the rest of that frame through EOP and hands the DMA page back to the ring (previously: NULL page left in the ring, leak, later NULL dereference). `allocatePacket()` NULL is handled.
- TX: on `igb_tx_map` failure the buffer slot is cleared so the mbuf is not freed twice later.
- Build: `./build.sh 5.12.0`; x86_64 only; Xcode 26.6 / macOS 26.5 SDK.
