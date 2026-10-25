# AppleIGB (MSI build) — Intel I210/I211/I350 driver for macOS Tahoe

A fork of the AppleIGB kext (Intel `igb` Linux driver ported to macOS) that fixes the
**"Ethernet works for a few minutes, then no traffic at all"** stall seen on macOS 26 Tahoe,
in particular with the Intel I211-AT on AMD X570 boards.

Status: tested on one machine (Gigabyte X570 Aorus Pro, Ryzen 9 5900X, I211-AT, OpenCore 1.0.8,
macOS 26.7.1). Two instrumented one-hour runs plus about 12 hours of daily use with 46 sleep/wake
cycles without a stall, where every earlier build stalled within minutes. More testers welcome:
please open an issue with your board, NIC, macOS version and the output of the diagnostics below.

## What was wrong

Every AppleIGB build so far (hnak, Shaneee, donatengit 5.11.4, ayushere 5.11.5–5.11.8) ran on the
**legacy INTx interrupt line**: the code that selects the MSI vector sat behind `#ifdef MSIX_ENABLED`,
which the Xcode project never defined. On this hardware the shared, level-triggered INTx line
eventually stops delivering interrupts, and because the driver never polls, RX and TX stop at the
same time. macOS notices through ARP first (`configd: Process router ARP failure: en0`), so it
looks like an IPv4 problem, but IPv6 connections fail just as hard.

The sibling driver AppleIGC (Intel I225/I226) fixed the same symptom the same way
([SongXiaoXi/AppleIGC PR 38](https://github.com/SongXiaoXi/AppleIGC/pull/38)).

## What this fork changes

- **MSI interrupts.** `initEventSources()` picks the first PCI message-signalled interrupt vector;
  legacy INTx remains the fallback. The `INT_ASSERTED` gate in the interrupt handler applies only
  in INTx mode. Boot-arg `igb-intx=1` forces the old line so both modes can be compared with the
  same binary (read from `IODeviceTree:/options`, no extra kernel KPI).
- **Interrupt handler always services the rings** (`igb_poll`) before handling link-change bits.
- **Diagnostics in the IORegistry.** `AppleIGB-DBG` (counters: interrupts, polls, watchdog ticks,
  RX/TX per ethertype, drops, checksum status, hardware MAC statistics, ring state) and
  `AppleIGB-Events` (last 128 events with wall-clock time: link changes, restarts, resets, hangs).
- **Latent panic fixes:** a failed `mbuf_copyback` in RX now discards the rest of that frame and
  recycles the DMA page (before: NULL page left in the ring); `allocatePacket()` NULL is handled;
  the TX slot is cleared when `igb_tx_map` fails (before: possible double free).
- **Accounting:** interface error counters are monotonic (netstat no longer shows Oerrs as
  multiples of 2^32), a TX queue stall is not counted as an error, RX packets are delivered in
  batches (`kInputOptionQueuePacket` + `flushInputQueue`).
- Everything from [ayushere v5.11.8](https://github.com/ayushere/AppleIGB) is kept: IPv6
  extension-header bounds checks, `MBUF_DONTWAIT` RX copy, TX ring lock.

Full history: [CHANGELOG.md](CHANGELOG.md). The previous README (ayushere) is in
[docs/README-ayushere-5.11.8.md](docs/README-ayushere-5.11.8.md).

## Supported devices

The personalities are unchanged from upstream: 82575, 82576, 82580, DH89xxCC, I210/I211
(0x1533–0x1539, 0x157B, 0x157C), I350, I354. Only the I211-AT (0x1539) has been tested with this build.

## Install (OpenCore)

1. Download `AppleIGB-<version>.kext.zip` from Releases and check the SHA-256 in the `.sha256` file.
2. Put `AppleIGB.kext` in `EFI/OC/Kexts` and add it to `Kernel → Add` like any other kext. The bundle
   identifier is still `com.amdosx.driver.AppleIGB`, so it is a drop-in replacement for an existing
   AppleIGB entry. If you keep an older AppleIGB for Sequoia, give that entry `MaxKernel 24.99.99`
   and this one `MinKernel 25.0.0` (that is how the test machine runs).
3. Reboot. Check with:

```bash
kmutil showloaded | grep AppleIGB
ioreg -r -c AppleIGB -l | grep -o '"irq_mode"=[0-9]*'      # 1 = MSI, 0 = legacy INTx
ioreg -r -c AppleIGB -l | grep -E 'AppleIGB-(DBG|Events)'
```

A one-hour recorder script for Tahoe is in `scripts/record-tahoe.command` (pings, ARP state,
interface counters, driver counters every 2 s into `~/Desktop/igb-rec-<date>.txt`).

## Build

Xcode 26 (the Command Line Tools cannot build kexts): `./build.sh 5.12.1` writes
`dist/AppleIGB-5.12.1.kext` (x86_64) and prints its SHA-256. The script expects Xcode at
`/Users/cw/Downloads/Xcode.app`; set `XCODE_APP=/Applications/Xcode.app` if yours is elsewhere.

## Credits

- Intel — `igb` Linux driver (5.11.4) and shared `e1000_*` code
- hnak — original macOS port (InsanelyMac)
- [Shaneee](https://github.com/Shaneee/AppleIGB), [donatengit](https://github.com/donatengit/AppleIGB) — 5.11.4 update, IntelMausi-style link management
- [ayushere](https://github.com/ayushere/AppleIGB) — Tahoe panic fixes (5.11.5–5.11.8)
- [SongXiaoXi/AppleIGC](https://github.com/SongXiaoXi/AppleIGC) — the MSI diagnosis on the sibling I225 driver

## License

GPL-2.0, inherited from the Intel `igb` driver and the earlier ports. See [LICENSE](LICENSE).
