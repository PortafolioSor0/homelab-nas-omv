# Hardware

Status: **Inventoried** (Phase 0 read-only discovery, 2026-09-29). Values come from the raw
inventory (see [phase-0-discovery.md](phase-0-discovery.md) §5). Items software cannot see are
marked `unknown — …` until the owner checks them physically.
Last updated: 2026-09-30 (Phase 2 SMART results)

> Serial numbers are recorded because they are the only reliable way to identify
> a disk. If this repository is ever made public, redact them first.

## 1. Server

| Item | Value |
|---|---|
| Hostname | `nas` (static hostname). Intended DNS name `nas.internal` does **not** currently resolve from the operator PC; the NAS is reached by IP (see [network.md](network.md)) |
| OS | Debian GNU/Linux 13.7 (trixie) |
| OpenMediaVault | `openmediavault` 8.5.9-1 (with `openmediavault-keyring` 1.0.2-2, `openmediavault-salt` 8.1.0) |
| Installed OMV plugins | None |
| omv-extras | No (no package, no apt source). mergerfs, snapraid, compose and luksencryption plugins have no install candidate in the configured repos; `openmediavault-sharerootfs` 8.0.1-1 is available |
| Kernel | `7.1.13+deb13-amd64` (Debian backports build `7.1.13-1~bpo13+1`; apt source `openmediavault-kernel-backports.list` present) |
| Chassis / board | ASRock H610M-ITX/eDP (Mini-ITX), DMI chassis type "desktop". Case model: unknown — owner to check physically |
| CPU | Intel Core i3-12100 (12th gen, 4 cores / 8 threads, max 4.3 GHz) |
| iGPU / GPU | Intel UHD Graphics 730 (Alder Lake-S GT1), driver `i915` in use. `/dev/dri` present: `card0` (group `video`), `renderD128` (group `render`). No discrete GPU |
| RAM | 16 GB = 2 × 8 GB DDR4-2667 (Timetec TIMETEC-U8G-2666), 2 of 2 slots used, board maximum 64 GB |
| ECC | No (DMI "Error Correction Type: None") |
| NIC(s) | Wired: Intel Ethernet Connection (17) I219-V (`e1000e`), interface `enp0s31f6`, in use; negotiated link speed unknown — not captured by the script (check OMV UI network interface details). Wireless: Intel Alder Lake-S CNVi Wi-Fi (`iwlwifi`), interface `wlp0s20f3`, down/unused. MAC addresses are kept only in the local raw output, never in Git |
| SATA ports / free bays | Intel H610 AHCI controller; kernel exposes 8 ATA ports (`ata1`–`ata8`), 2 disks attached. Physical SATA connectors / M.2 slots and free drive bays: unknown — owner to check board and case physically |
| PSU | unknown — owner to check physically (model, wattage) |
| UPS | None known — owner to confirm |
| BIOS/UEFI | American Megatrends 12.02 (2025-10-08), UEFI boot (EFI system partition mounted at `/boot/efi`). BIOS admin password: unknown — owner to check in BIOS setup |

## 2. Disks

Exactly **2** physical disks were found. `/dev/sdX` names are informational only: they can change
between boots (the `/etc/fstab` comments show the OS disk was `sda` during installation; it is
now `sdb`). Identify disks by serial and `/dev/disk/by-id/` name.

| Role | Label | Model | Serial | Capacity | Interface | by-id | FS UUID | Partition state | Mount state | Current dev name | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| OS | — | TOSHIBA KSG60ZMV256G M.2 2280 256GB | SSDEXAMPLE01 | 256.06 GB / 238.47 GiB (0.23 TiB) | M.2 **SATA** SSD, SATA 3.3, 6.0 Gb/s | `ata-TOSHIBA_KSG60ZMV256G_M.2_2280_256GB_SSDEXAMPLE01` | `/` ext4 `bbbbbbbb-1111-4222-8333-444444444444`; EFI vfat `ABCD-1234`; swap `cccccccc-1111-4222-8333-444444444444` | GPT: p1 976M EFI (vfat), p2 225.2G Linux (ext4), p3 12.3G swap | `/` (221G, 2.6G used, 207G free), `/boot/efi`, swap active | `/dev/sdb` | **NEVER a data disk. NEVER wipe.** |
| data1 | `data1` | ST2000NM0055-1V4104 (Seagate Enterprise Capacity 3.5 HDD, 7200 rpm) | HDDEX001 | 2.00 TB / 1.82 TiB | SATA HDD, SATA 3.1, 6.0 Gb/s, direct on AHCI (no USB bridge) | `ata-ST2000NM0055-1V4104_HDDEX001` (partition: `…_HDDEX001-part1`) | ext4 `aaaaaaaa-1111-4222-8333-444444444444` | GPT, 1 partition (whole disk), ext4, 4 KiB blocks, 488378385 blocks, reserved 1 % = 4883783 blocks (D-16) | `/srv/dev-disk-by-uuid-aaaaaaaa-1111-4222-8333-444444444444` (OMV-managed fstab by UUID, `nofail`, acl, user/group quota) | `/dev/sda` | Formatted in Phase 3 (2026-09-30). **No redundancy, no backup yet** (D-10) |

### Disk health (SMART, read on 2026-09-29)

| Disk (serial) | Overall | Power-on hours | Reallocated | Pending | Offline-uncorrectable | UDMA CRC errors | SSD wear | Other |
|---|---|---|---|---|---|---|---|---|
| HDDEX001 (HDD) | PASSED | 40 | 0 | 0 | 0 | 0 | n/a | Reported-uncorrect 0; no errors logged; **no self-test ever run**; 20 power cycles; 27 °C (lifetime 19–29 °C); 0 sectors written |
| HDDEX001 (HDD), after Phase 2 long test (2026-09-30) | PASSED | 56 | 0 | 0 | 0 | 0 | n/a | **Extended self-test: Completed without error** (at 48 h). Reported-uncorrect 0, End-to-End 0, Command_Timeout 0, Spin_Retry 0; 20 power cycles; 30 °C; **0 LBAs written** (still blank). Raw_Read_Error_Rate / Seek_Error_Rate / Hardware_ECC_Recovered raw values are Seagate composite counters with normalized values well above threshold (not errors) |
| SSDEXAMPLE01 (SSD) | PASSED | 7433 | 0 | not reported (attribute absent) | not reported (attribute absent) | 0 | **Percentage Used 30 %**; Wear_Leveling_Count normalized 72; available spare (Unused_Rsvd_Blk_Cnt_Tot) normalized 100 | Reported-uncorrect 0; no errors logged; 1437 power cycles; **Time in Over-Temperature 55260 min**, lifetime max 76 °C (spec max 40 °C); last short self-tests "Aborted by host" at 7429 h; now 31 °C |

## 3. Disk history / events

| Date | Disk (serial) | Event |
|---|---|---|
| 2026-09-29 | SSDEXAMPLE01 | Inventoried in Phase 0 (POH 7433 h) |
| 2026-09-29 | HDDEX001 | Inventoried in Phase 0 (POH 40 h) |
| 2026-09-30 | SSDEXAMPLE01 | Phase 2: short self-test **Completed without error** at 7437 h (the earlier "Aborted by host" and "Interrupted (host reset)" entries at 7429 h are superseded). SMART monitoring and scheduled tests enabled |
| 2026-09-30 | HDDEX001 | Phase 2: extended self-test (206 min) **Completed without error** at 48 h. All error counters 0. SMART monitoring and scheduled tests enabled. Cleared for Phase 3 (D-04) |
| 2026-09-30 | HDDEX001 | Phase 3: GPT + 1 partition + ext4 created via the OMV UI (about 13:02), mounted by OMV. UUID `aaaaaaaa-1111-4222-8333-444444444444`. Then `tune2fs` label `data1` and reserved 1 % |

## 4. Future hardware considerations

- Number of free SATA ports and drive bays limits how far mergerfs/SnapRAID can
  grow; an HBA (LSI in IT mode) may be needed later.
- UPS sized for clean shutdown (NUT-compatible, USB) — see decision D-13.
- A second SSD for application data / databases (decision D-11). The current OS SSD is
  used (30 % endurance consumed, long over-temperature history), which strengthens this.
- Cooling/airflow for additional HDDs (monitor temperatures in Phase 2/12).
