# Handoff — AppleIGB eigen build (stand 25 oktober 2026)

## Waar staat wat
- Repo: `~/Desktop/AppleIGB-build/own` (zelfde kopie op Sequoia en Tahoe), publiek op https://github.com/corneliswest/AppleIGB (branch `main`, tags `v5.12.0`, `v5.12.1`, release v5.12.1 met zip + SHA-256). Commits zonder Claude-vermelding, e-mail `corneliswest@users.noreply.github.com`.
- EFI (disk0s1, 2 TB Samsung): `EFI/OC/Kexts/AppleIGB-Tahoe.kext` = **5.12.1** (MinKernel 25.0.0), `AppleIGB.kext` = 5.11.4 voor Sequoia (MaxKernel 24.99.99). Terugvaloptie `EFI/OC/AppleIGB-Tahoe-5.12.0.kext.bak`. Volledige EFI-back-up: `~/Desktop/EFI-backup-20261025-1328` (Tahoe- en Sequoia-bureaublad kunnen verschillen; de back-up staat op het volume waar hij gemaakt is).
- Mounten (gebruiker typt wachtwoord): `sudo diskutil mount disk0s1` → `/Volumes/NO NAME`. Installeren: `scripts/install-efi.sh dist/AppleIGB-<versie>.kext` (back-up, hashcontrole, ontkoppelen; raakt config.plist niet aan).
- Xcode: op Sequoia `~/Downloads/Xcode.app` (26.6). Op Tahoe staan `~/Downloads/Xcode_26.6_Universal.xip` en `Xcode_26.3_Universal.xip`; uitpakken en `XCODE_APP=/pad/naar/Xcode.app ./build.sh <versie>`.

## Wat het probleem was en wat er is gefixt
Zie README.md en CHANGELOG.md. Kort: alle eerdere builds draaiden op de legacy INTx-interrupt; op X570 viel die na minuten stil (RX en TX tegelijk, configd meldt `router ARP failure`). 5.12.x gebruikt MSI. Test 8 en 9 schoon, daarna ~12 uur gebruik met 46 slaap/wek-cycli zonder uitval.

## Diagnose zonder herbouwen
- `kmutil showloaded | grep AppleIGB` (versie), `ioreg -r -c AppleIGB -l | grep -E 'AppleIGB-(DBG|Events)'` (tellers en gebeurtenissen; `irq_mode`=1 is MSI).
- `scripts/record-tahoe.command` (60 min opname naar `~/Desktop/igb-rec-<datum>.txt`), `scripts/dmesg-dump.command` bij uitval (sudo).
- Vanuit Sequoia: `scripts/read-tahoe-logs.sh "JJJJ-MM-DD UU:MM:SS"` leest de Tahoe-logs (gebruik `/usr/bin/log`, niet `log`: zsh-builtin).
- Boot-arg `igb-intx=1` dwingt de oude INTx-lijn af (A/B-test met dezelfde binary).

## Werkregels (uit de oorspronkelijke HANDOFF)
Voorstel eerst, dan uitvoeren. Eén variabele per test. Vóór elke EFI-wijziging een back-up (config.plist als `config.plist.bak-<datum>-<test>`), daarna `plutil -lint` en ocvalidate (OpenCore 1.0.8; niet lokaal aanwezig, SHA-256 van de release-zip staat in `~/Downloads/HANDOFF.md`). sudo en mounten doet de gebruiker. Nooit de 1 TB (Windows) aanraken.

## Open punten
1. `Misc → Debug → Target` staat op 67 (256 KB OpenCore-log per boot); naar 3 zetten en het verouderde kext-commentaar ("debug-build 5.11.43") bijwerken: configwijziging met back-up en ocvalidate.
2. Reactie van ayushere op https://github.com/ayushere/AppleIGB/issues/4 afwachten; daarna eventueel een PR vanuit `own/`.
3. `netstat` Ipkts blijft 0 (kernel-boekhouding, cosmetisch).
4. Nog openstaand bij uitval: 5.12.2 met watchdog-polling als vangnet (`igb_poll` vanuit `watchdogTask`, watchdog opnieuw starten na `intelRestart`/`setLinkDown`, TX-hang → `igb_reinit_locked`), en als de events `PCIE_LOST` tonen: herstel in `e1000_read_reg` plus OpenCore `pci-aspm-default=0` op `PciRoot(0x0)/Pci(0x1,0x2)/Pci(0x0,0x0)/Pci(0x4,0x0)/Pci(0x0,0x0)` (eerst met gfxutil controleren).
5. Los van de LAN-kext (zie `~/Desktop/Hackintosh-handoff-2026-10-25.md` op Tahoe): USB-map met USBToolBox, NVMeFix aanzetten, Bluetooth ontbreekt fysiek.
