# Architectural decisions

Status legend: **OPEN** · **PROPOSED** (recommendation given, awaiting owner) · **DECIDED**
Last updated: 2026-09-30

"Blocks" = the latest point by which the decision must be made.

## Summary

| ID | Decision | Blocks | Status |
|---|---|---|---|
| D-01 | Encryption at rest (LUKS) for data disks | **Formatting data1 (Phase 3)** | DECIDED (A: none) |
| D-02 | Filesystem for data disks | **Formatting data1** | DECIDED (ext4) |
| D-03 | Partitioning / labeling convention | **Formatting data1** | DECIDED |
| D-04 | Disk testing depth before format | **Formatting data1** | DECIDED (SMART short + long) |
| D-05 | mergerfs pool from day one (single branch) vs direct disk paths | **Creating shared folders (Phase 4)** | DECIDED (B: directly on data1) |
| D-06 | Confirm 2 TB disk holds no needed data | **Formatting data1** | DECIDED (blank, nothing needed) |
| D-07 | Photo library model (Immich-managed vs external library) | Phase 9 | DEFERRED to Phase 9 (Phase 4 creates only `photos/`) |
| D-08 | Top-level directory layout (tier-aligned) | Phase 4 | DECIDED (flat on data1: `private-alex`, `private-sam`, `shared-family`, `photos`, `media`, `backups`) |
| D-09 | Account names and UID/GID scheme | Phase 5 (before any file ownership is set) | DECIDED (`alex`, `sam`, group `family`; service accounts per phase) |
| D-10 | Tier 1 migration policy (NAS never sole copy before backups) | **Before copying Tier 1 data to NAS** | DECIDED |
| D-11 | App state / DB placement (OS SSD vs second SSD) | Phase 7 | DECIDED (A: OS SSD, 2026-10-03) |
| D-12 | Tailscale placement and mode | Phase 11 | OPEN |
| D-13 | UPS | Before Tier 1 data / databases on NAS (recommended) | OPEN |
| D-14 | Nextcloud vs SMB + VPN | Phase 10 | PROPOSED (not Nextcloud for now) |
| D-15 | Off-site backup target and tool | Phase 13 (ideally before Tier 1 migration) | OPEN |
| D-16 | ext4 reserved-block percentage | Any time (reversible) | DECIDED (1 % on data disks) |
| D-17 | Hardware transcoding | Phase 8 | DECIDED (A: Intel QSV/VA-API via renderD128, 2026-10-06) |
| D-18 | NAS IP addressing | Phase 1 | DECIDED (static `192.168.10.250` in OMV) |

---

## Decisions that must be made BEFORE the 2 TB disk is formatted

### D-01 — Encryption at rest

Encryption can only be added later by reformatting (i.e. moving all data off first).

| Option | Protects against | Costs |
|---|---|---|
| A. None | — | Simplest; failed/retired disks leak data unless physically destroyed |
| B. LUKS per disk, auto-unlock with keyfile stored on OS SSD | Failed disk sent for RMA/disposed, single disk stolen | Keyfile must be backed up offline; recovery of each disk needs the key; whole-server theft **not** protected |
| C. LUKS per disk, manual unlock after each boot | Also whole-server theft | Every reboot/power cut requires manual unlock before shares/containers work; poor fit for unattended recovery |

**Recommendation: B**, *if* the OMV 8 LUKS plugin (`openmediavault-luksencryption`)
supports it cleanly with mergerfs/SnapRAID on top — to be verified before Phase 3.
Otherwise A, with the rule that dead disks are physically destroyed rather than
returned. SnapRAID works on top of LUKS-mapped filesystems. Keys go into the
password manager + an offline copy.

**Decided 2026-09-29 by owner:** option A, no encryption at rest. Disposal rule: a working disk is
fully overwritten before it is sold or given away; a failed disk that cannot be overwritten is
physically destroyed, not returned for RMA or sold. Evidence: `openmediavault-luksencryption` has
no install candidate in the configured repos (omv-extras not installed); the owner judged the risk
of losing the key and the harder recovery to outweigh the disposal risk (Phase 0 inventory,
2026-09-29). Changing this later requires emptying and reformatting the disk.

### D-02 — Filesystem: **ext4** (see storage.md §3)

Proposed: ext4 for all data disks. XFS or split parity files only for parity
disks > 16 TiB.

**Decided 2026-09-29 by owner:** ext4 for all data disks, starting with `data1`. Evidence: the
2 TB disk (ST2000NM0055-1V4104, serial HDDEX001) is 2.00 TB / 1.82 TiB, far below the 16 TiB
limit; ext4 is what OMV creates natively (Phase 0 inventory, 2026-09-29).

### D-03 — Partitioning and labels

Proposed: create the filesystem through the OMV UI (**Storage → File Systems → Create**),
which uses a GPT table and a single partition on the whole disk. Label `data1`.
No manual `mkfs`/`parted`. Menu names to be verified in OMV 8 at the time.

**Decided 2026-09-29 by owner:** filesystem created through the OMV UI (GPT, one partition on the
whole disk), label `data1`, no manual `mkfs`/`parted`. Evidence: the disk currently has no
partition table and no filesystem signature; OMV 8.5.9-1 is installed (Phase 0 inventory,
2026-09-29).

**Implementation note (2026-09-30):** the filesystem created through the OMV UI had no label. It was
set afterwards with `tune2fs -L data1`. For future disks, check the label right after creation.

### D-04 — Disk testing depth before format

The ST2000NM0055 is an enterprise model often sold used/refurbished.

| Option | Duration (2 TB) | Destructive |
|---|---|---|
| SMART short + long self-test | ~4 h | No |
| + `badblocks -w` full write/read pass (1 pattern) | +~8–10 h | **Yes** — wipes the disk |

Proposed: SMART long test always (Phase 2). If power-on hours are high or any
reallocated/pending sectors exist, also a single-pattern destructive pass —
only after D-06 confirms the disk is empty, with explicit approval.

**Decided 2026-09-29 by owner:** SMART short + long self-test only (Phase 2); no destructive
`badblocks` pass. Evidence: ST2000NM0055-1V4104, serial HDDEX001: 40 power-on hours, reallocated 0,
pending 0, offline-uncorrectable 0, UDMA CRC 0, no errors logged, SMART PASSED; the drive reports a
206-minute extended self-test (Phase 0 inventory, 2026-09-29). If the long test reports any error,
this decision is reopened.

### D-05 — mergerfs from day one

| Option | Pros | Cons |
|---|---|---|
| A. Single-branch mergerfs pool now; all shared folders on the pool | Paths never change when disks are added; no migration later | FUSE overhead now for no capacity gain; dependency on the mergerfs plugin from the start |
| B. Shared folders directly on `data1`; introduce pool later | Simpler today | Later every shared folder, share and container mount must be re-pointed or data moved |

**Recommendation: A.** Re-pointing shares and containers later is exactly the
kind of change that causes permission and path mistakes.

**Decided 2026-09-30 by owner: B.** Shared folders go directly on `data1`, with no mergerfs and no
omv-extras for now. Accepted consequence: when a second data disk is added, every shared folder,
SMB share and container mount must be re-pointed to the pool path (or data moved). That will be a
planned, approval-gated migration at that time (storage.md §6/§7). omv-extras is still expected in
Phase 7 (Compose).

### D-06 — Contents of the 2 TB disk

Must be confirmed by discovery (partition table, filesystem signatures, mount
state) **and** by you: "nothing on this disk is needed". If unsure, mount it
read-only and inspect before anything else.

**Decided 2026-09-29 by owner:** the 2 TB disk holds no needed data; the owner states the disk is
new. Evidence: ST2000NM0055-1V4104, serial HDDEX001, by-id `ata-ST2000NM0055-1V4104_HDDEX001`:
no partition table (`fdisk -l`), no filesystem signature (`blkid -p` empty), not mounted, not in
`/etc/fstab`, lifetime Logical Sectors Written 0, 40 power-on hours (Phase 0 inventory, 2026-09-29).

### D-08 — Top-level layout

Proposed: tier-aligned layout in storage.md §4.2 (`private/`, `shared/`,
`photos/`, `media/`, `backups/`), app state on SSD. Not strictly pre-format, but
must be approved before Phase 4.

**Decided 2026-10-01 by owner:** the §4.2 layout, directly on `data1` (D-05 = B). Personal areas
are `private/alex` (owner) and `private/sam` (relative). These names will also be used for their
data accounts in Phase 5 (D-09). Photos: all users' photos live under `photos/`. Privacy between
family members is enforced by **Immich app accounts** (private timelines, shared albums or partner
sharing), not by folders. Therefore `photos/` is **never SMB-shared to family accounts**: only
Immich's service account and admin access it. `shared/family` is for non-photo files. Subfolders of
`photos/` are decided in Phase 9 (D-07).

**Amended 2026-10-03 by owner (flat layout):** OMV created the shared folders as top-level
directories named after the folder (`private-alex`, `private-sam`, `shared-family`, `photos`,
`media`, `backups`) instead of `private/alex` etc. The owner chose to keep this (option A). The tier
is read from the name prefix, and there are no intermediate directories.

### D-10 — Tier 1 migration policy

Proposed rule: **until Phase 13 backups exist and one restore has been tested,
the NAS is never the only copy of any Tier 1 file.** Originals stay on the
source devices. Tier 3 media can move earlier.

**Decided 2026-09-29 by owner:** until Phase 13 backups exist and one restore has been tested, the
NAS is never the only copy of any Tier 1 file; originals stay on the source devices; Tier 3 media
may move earlier. Evidence: Phase 0 inventory found no backups and no second data disk (2 disks
total: OS SSD + one 2 TB HDD), so there is no redundancy yet.

---

## Decisions for later phases

### D-07 — Photo library model (Phase 4/9)

- **Immich-managed upload library:** Immich organizes originals using a storage
  template (e.g. `year/month/…`) — readable folders if the storage template is
  enabled. Best for phone backup.
- **External library (read-only mount):** existing folders stay as they are;
  Immich only indexes them. Best for historical archives.
- Proposed: **both** — phone uploads into Immich's library with storage template
  on; historical photos in a separate read-only external library. The photo files
  on disk remain the source of truth; the Immich DB is rebuildable metadata
  (albums/faces would be lost without DB backups, so DB is still backed up).

**Deferred 2026-09-30 by owner to Phase 9.** Phase 4 creates only the top-level `photos/`
area. Its subfolders are decided when Immich is installed.

### D-09 — Accounts and UID/GID scheme (Phase 5)

Proposed:
- Human accounts (OMV creates from UID 1000): `owner-admin` (sudo, SSH, OMV
  admin group — no SMB), `owner` (data), `relative` (data). Real names TBD.
- Service accounts in a reserved fixed range, e.g. UID/GID 2000–2099
  (`svc-jellyfin`, `svc-immich`, …), no shell, no password, never SMB-enabled.
- Groups created only when a second member exists (e.g. `family` for `shared/family`,
  `media-rw` for accounts that may add media, `media-ro` for Jellyfin).
  Groups like `project-users`/`cloud-users` are deferred until there is a real
  need (YAGNI).
- UID/GID numbers recorded in users-and-permissions.md because container
  `user:` settings and on-disk ownership depend on them.

**Decided 2026-10-03 by owner:**
- Admin account `owner-admin` (exists, Phase 1.6). Data accounts **`alex`** (owner) and **`sam`**
  (relative): shell `/usr/sbin/nologin`, no SSH, no sudo, no extra groups. Their passwords come from
  the password manager and become their SMB/app passwords later.
- Group **`family`** = {alex, sam}, for `shared-family`.
- Service accounts in UID/GID 2000–2099 are **created in the phase that needs them** (Jellyfin 8,
  Immich 9), not now. Until then `photos` and `backups` stay root-only.
- `media`: managed by `alex`. `sam` has **no filesystem access** and watches through her Jellyfin
  app account.
- Access is never granted through the `users` group (GID 100).

### D-11 — App state and databases (Phase 7)

**DECIDED 2026-10-03 (owner: "R D-11") — A: OS SSD.** `/var/lib/docker` stays at the default
location and app config/DBs go in an `appdata` shared folder on the root filesystem (via
`openmediavault-sharerootfs`). At decision time `/` had 207 GiB free of 221 GiB. Accepted trade-off:
the used SSD (F-10, 30 % wear) is a single point of failure for app state, so Tier 2 backups are
mandatory before Immich holds real data. Revisit (option B: second SSD) on wear/capacity.

Proposed: OS SSD via `openmediavault-sharerootfs` for now (verify capacity in
discovery; keep ≥ 20 % free), daily backups to HDD + off-site. Revisit a
dedicated SSD if Immich/Jellyfin metadata growth or SSD wear warrants it.

### D-12 — Tailscale (Phase 11)

Options: host package vs container; plain node vs subnet router; Tailscale SSH
vs OpenSSH. Leaning: host package, plain node (no subnet router), OpenSSH kept,
ACLs restricting `relative`'s devices to SMB (445) only. To be decided in Phase 11.

**Owner requirement (2026-10-03):** `sam` is not technical, so remote access must need **zero
action on her part**. The owner sets up and logs in her iPhone once. The connection must be
automatic (e.g. Tailscale "VPN On Demand" / always-on), and the Files/Immich/Jellyfin entries must
use a name that works both at home and away. The design must be evaluated against this in Phase 11.

### D-13 — UPS

Power loss during writes risks filesystem and database corruption and SnapRAID
sync interruption. Proposed: small line-interactive UPS with USB, clean shutdown
via NUT (OMV plugin `openmediavault-nut`). Budget decision for the owner.

### D-14 — Private cloud: SMB + Tailscale first, Nextcloud not for now

Needs listed: private storage for relative, access from outside the home, photo
backup. SMB over Tailscale covers file access; Immich covers photo backup.
Nextcloud adds a PHP app, a database, a second permission model and a larger
attack surface. Re-evaluate only if a concrete need appears (browser-only access
from devices that cannot run Tailscale, public share links, calendar/contacts sync,
mobile file sync with offline copies).

**New input (owner, 2026-10-03):** both users are on iPhone (plus Windows, and Linux soon), and the
owner wants an **iCloud-like experience, especially for `sam`**. Photos are covered by the Immich
iOS app (automatic background upload, private timeline, shared albums). For files, SMB in the iOS
Files app works but is not iCloud-like (no offline copies or sync). This is the "mobile file sync"
trigger above, so D-14 must be **re-evaluated in Phase 10** (candidates: SMB + Files app, Nextcloud,
Seafile, or similar iOS file-provider apps), weighing simplicity for `sam` against attack surface.
Status stays PROPOSED until then.

### D-15 — Off-site backup (Phase 13)

Options: cloud object storage (e.g. Backblaze B2, Hetzner Storage Box) with
restic/borg/Kopia (client-side encryption, versioning, append-only/immutable where
possible), or a disk kept at another location (e.g. a family member's house).
Tier 1 size estimate needed to price this.

### D-16 — ext4 reserved blocks

Proposed 1–2 % on data disks; reversible via `tune2fs -m` at any time (still a
command that requires approval).

**Decided 2026-09-30 by owner:** 1 % on data disks. OMV 8 creates ext4 with 0 % reserved, so
every new data disk needs `tune2fs -m 1` after it is created. `data1` (HDDEX001-part1): 4883783
blocks, about 18.6 GiB. Rationale: stop non-root writers (SMB users, service UIDs) before the disk is
100 % full, and keep headroom for SnapRAID parity overhead later.

### D-17 — Hardware transcoding

Depends on CPU/iGPU found in discovery. No transcoding configuration until then.

**DECIDED 2026-10-06 (owner "R") — A:** only `/dev/dri/renderD128` is passed to the container plus
`group_add` render (GID 992). No `privileged`, no boot/kernel change. Low-power encoders (GuC/HuC)
stay off unless a boot change is approved separately.

Phase 0 facts (2026-09-29): CPU Intel Core i3-12100 (12th gen); iGPU Intel UHD Graphics 730
(Alder Lake-S GT1), driver `i915` in use; `/dev/dri/card0` (group `video`) and
`/dev/dri/renderD128` (group `render`) present; no discrete GPU. Decided in Phase 8 (above).

### D-18 — IP addressing

Proposed: DHCP reservation on the router (no network change on the NAS → no
lockout risk). Static configuration in OMV only if the router cannot reserve.

**Decided (owner, 2026-09-30):** static IP in OMV, `192.168.10.250/24`, with gateway and DNS
`192.168.10.1`. The router is ISP-managed and the owner prefers not to involve the ISP. `.250` was
picked high to avoid the unknown DHCP pool. Accepted risk: a possible IP conflict if the router
leases `.250`. Rollback: `omv-firstaid` → Configure network interface → DHCP.
