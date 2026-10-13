# Storage

Status: **Phase 3**: `data1` formatted and mounted (2026-09-30). The pool/shares are not created yet.
Last updated: 2026-09-30

## 1. Current state (Stage 1)

```
SSD  TOSHIBA KSG60ZMV256G (M.2 SATA, ~238 GiB)   currently /dev/sdb
└── OpenMediaVault 8 root filesystem        ← NEVER a data disk, NEVER wiped

HDD  Seagate ST2000NM0055 (~1.82 TiB), serial HDDEX001   currently /dev/sda
└── part1: ext4 "data1", UUID aaaaaaaa-1111-4222-8333-444444444444, reserved 1 %
    mounted by OMV at /srv/dev-disk-by-uuid-aaaaaaaa-1111-4222-8333-444444444444
```

- `/dev/sdX` names are **not** stable identifiers (note the OS disk is `sdb`,
  not `sda`). Every disk operation identifies disks by **model + serial +
  capacity**, then by `/dev/disk/by-id/…` and filesystem UUID.
- No RAID. RAID with one disk is meaningless and makes later expansion harder.
- **There is no redundancy at Stage 1.** Until backups exist (Phase 13), the
  NAS must not hold the *only* copy of any Tier 1 file. Do not delete originals
  from phones/PCs after copying them to the NAS.

## 2. Target design: one filesystem per disk + mergerfs + SnapRAID

```
 data disks (any sizes)                         parity disk(s)
 ┌────────┐ ┌────────┐ ┌────────┐               ┌────────────────┐
 │ data1  │ │ data2  │ │ data3  │               │ parity1        │
 │ 2 TB   │ │ 4 TB   │ │ 8 TB   │               │ ≥ largest data │
 │ ext4   │ │ ext4   │ │ ext4   │               │ ext4           │
 └───┬────┘ └───┬────┘ └───┬────┘               └───────▲────────┘
     └──────────┼──────────┘                            │
                ▼                                       │ snapraid sync (scheduled)
       mergerfs pool  /srv/mergerfs/pool  ──────────────┘ snapraid scrub (scheduled)
                │
   shared folders, SMB shares, container bind mounts
```

### 2.1 Why this design

| Requirement | How it is met |
|---|---|
| Mixed disk sizes | Each disk has its own filesystem; mergerfs merges them; no capacity lost to matching |
| Add one disk at a time | Format new disk → add as mergerfs branch → add to SnapRAID config |
| Each disk independently readable | Plain ext4 — any Linux machine can mount a single disk and read its files |
| Limited blast radius | Losing more disks than parity covers only loses files on the failed disks, not the whole pool |
| Efficient capacity | Only the parity disk(s) are "overhead" |

### 2.2 Honest limitations

- **SnapRAID is not real-time.** Files written after the last `sync` are unprotected
  until the next `sync`. Deleted/modified files can be *undeleted* only if the
  previous sync still covers them.
- **SnapRAID is not a backup.** It does not protect against ransomware that is
  synced into parity, controller failure that corrupts multiple disks, fire, theft,
  or user error older than the last sync.
- **Frequently changing data degrades SnapRAID.** A file modified after `sync`
  can make recovery of *other* disks' files at the same parity positions fail.
  Therefore databases, container state, caches and rolling backups must be either
  on the SSD or **excluded** from SnapRAID.
- **mergerfs is FUSE.** Slightly more CPU/latency than a native mount; no
  hardlinks across disks; databases should never live on it.
- **No snapshots on ext4.** File versioning must come from the backup tool
  (e.g. restic/borg with retention), not from the filesystem.

## 3. Filesystem choice for data disks

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **ext4** | Mature, OMV default, readable everywhere, `e2fsck` recovery tooling, SnapRAID's most tested pairing | No checksums, no snapshots | **Recommended** |
| XFS | Good with large files, parity files >16 TiB | Can't shrink, less forgiving recovery on single disks | Consider for **parity** disks > 16 TB only |
| btrfs (single) | Data checksums, snapshots (`snapraid-btrfs`) | More complexity, more moving parts, OMV/SnapRAID integration less common | Not now |

SnapRAID `scrub` provides bit-rot *detection and repair* for protected data,
which covers much of what btrfs checksums would add.

**Parity disks > 16 TiB:** ext4 with 4 KiB blocks has a 16 TiB maximum *file*
size. SnapRAID supports splitting a parity level across multiple files, or the
parity disk can use XFS. Decide when buying a parity disk > 16 TB.

### 3.1 ext4 reserved blocks

ext4 reserves 5 % by default for root. On a 2 TB data disk that is ~93 GiB.
- Keeping some reserve is useful: SnapRAID parity has per-file overhead, so
  data disks that are exactly as large as the parity disk must not be 100 % full.
- Proposed: reduce to ~1–2 % on data disks later (non-destructive, `tune2fs -m`,
  reversible), keep the parity disk strictly ≥ largest data disk.

## 4. Proposed directory / shared-folder layout (evaluation of the initial draft)

### 4.1 Problems with the initial draft

| Draft item | Issue | Change |
|---|---|---|
| `media/personal-videos` | Mixes Tier 1 into a Tier 3 tree; would be skipped by "don't back up media" rules | Move to `photos/` (personal media library) |
| top-level `documents/`, `projects/`, `digital-products/` | These are the **owner's private** data; as top-level shares they are one ACL mistake away from being visible to family | Place under the owner's private area |
| `users/` + `shared/` + other top-levels mixing tiers | Tier not derivable from path | Tier-aligned top levels |
| `backups/` on the same pool | Fine for copies of **SSD state**; useless for backing up pool data | Keep, but scope it explicitly; exclude from SnapRAID |
| `appdata/` on HDD pool | Databases on FUSE/HDD; churn breaks SnapRAID | Move to SSD |

### 4.2 Layout (D-08 DECIDED 2026-10-01; flat variant 2026-10-03; root itself is **not** shared)

Created directly on `data1` (D-05 = B: no mergerfs pool yet). **Flat:** every area is a top-level
directory named after its OMV shared folder. The tier is read from the name prefix
(`private-*`, `shared-*` = Tier 1). Nested `private/<user>` was dropped (owner choice 2026-10-03).
A side benefit is that no intermediate directory reveals which personal areas exist.

```
/srv/dev-disk-by-uuid-aaaaaaaa-1111-4222-8333-444444444444/   (data1; referenced via shared folders)
├── private-alex/                   Tier 1 — owner only (documents, university, projects, … created by her)
├── private-sam/                   Tier 1 — relative only
├── shared-family/                  Tier 1 — explicitly shared family area (non-photo files); group: family
├── photos/                         Tier 1 — all users' photos & personal videos; Immich-only access,
│                                     never SMB-shared to family (privacy is per Immich account).
│                                     Subfolders decided in Phase 9 (D-07)
├── media/                          Tier 3 — Jellyfin read-only
│   ├── movies/
│   ├── tv/
│   └── music/
└── backups/                        Tier 2 copies of SSD state — excluded from SnapRAID
    ├── omv-config/
    ├── appdata/
    └── db-dumps/
```

Each top-level area is its **own OMV shared folder** (same name), with its own permissions and,
where needed, its own SMB share. Nothing is shared as "the whole disk/pool". As created in
Phase 4, all six are `root:users`, mode `2700` (`drwx--S---`): no access for the `users` group or
others until Phase 5 grants it per account/group.

### 4.3 SSD layout (D-11 = A; `appdata` created 2026-10-06, Phase 7.4)

```
OS SSD (root filesystem)
├── /var/lib/docker  Docker images/layers (daemon.json data-root; re-pullable)
└── /appdata         OMV shared folder `appdata` via sharerootfs, root:users 2700
    ├── compose/        Compose files (mirrors ./compose in this repo, secrets in .env)
    ├── jellyfin/       config + metadata (+ cache/trickplay if capacity allows)
    └── immich/         config, Postgres data, (thumbnails if capacity allows)
```

OMV does not allow shared folders on the OS filesystem by default; the
`openmediavault-sharerootfs` plugin (omv-extras) is the supported way. To be
verified for OMV 8 in Phase 7. The OS disk is **not** repartitioned.

SSD capacity budget (to be verified in discovery): ~238 GiB total; OS ~10–20 GiB;
Docker images ~10–30 GiB; Postgres ~1–5 GiB; Jellyfin metadata can grow large
(tens of GiB with trickplay); Immich thumbnails ≈ 5–10 % of photo library size.
Keep ≥ 20 % free.

## 5. SnapRAID plan (future)

- Parity disk(s) ≥ largest data disk. One parity = survive 1 disk failure.
  Consider 2-parity at ~5+ data disks.
- `snapraid.content` files stored on at least **parity count + 1** different disks
  (e.g. OS SSD + every data disk).
- **Included:** `private-*/`, `shared-*/`, `photos/` (originals; subfolders per D-07), `media/`.
- **Excluded:** `backups/`, `photos/import/` (transient), any cache/transcode
  folders, `lost+found`, temp/partial download files.
- Schedule: `sync` daily (or after large imports), `scrub` a portion weekly
  (e.g. 8–12 % of the array, older than N days). Abort `sync` automatically if
  deletions exceed a threshold (protects against mass deletion/ransomware
  being written into parity). Tooling: OMV `openmediavault-snapraid` plugin
  (verify OMV 8 support) — prefer plugin over hand-rolled cron.

## 6. mergerfs plan

- Pool created with the OMV `openmediavault-mergerfs` plugin (verify OMV 8 support).
- **Proposal (D-05):** create the pool with a **single branch (data1) from day one**,
  so every shared folder, share and container mount uses the pool path. Adding
  disks later changes nothing for clients.
- Create policy candidates:
  - `epmfs` (existing path, most free space) — keeps directories together on one
    disk; better for "each disk independently useful"; can fill one disk if a
    top-level dir only exists there.
  - `pfrd` / `mfs` — balances writes across disks; files of one album/project may
    scatter across disks.
  - Proposal: `epmfs` with a `minfreespace` margin, revisit when disk #2 arrives.
- `moveonenospc=true`, `cache.files` per current mergerfs docs; confirm options
  against the mergerfs version shipped for OMV 8.

## 7. Expansion strategy

### 7.1 Procedure for every new disk (mandatory)

1. Identify conclusively: model, serial, capacity, `/dev/disk/by-id`, bay/cable.
2. SMART: `smartctl -a` baseline (reallocated/pending/uncorrectable, hours).
3. Test: SMART long test; for used/refurbished disks, optionally a full
   burn-in (**destructive** `badblocks -w` only on an empty disk with explicit approval).
4. Confirm no required data exists on it.
5. Format **only after explicit approval** (OMV UI, ext4, label `dataN`/`parityN`).
6. Add to the appropriate layer (mergerfs branch or SnapRAID parity).
7. Verify pool (capacity, write test, branch visibility).
8. Verify permissions (no new world-readable paths).
9. Verify parity (`snapraid sync` + `status`) and backups.
10. Document in `hardware.md`, `storage.md`, `CHANGELOG.md`.

### 7.2 Which disk becomes what — "parity promotion"

Parity must be ≥ the largest data disk. When a new disk is **larger** than the
current parity disk, the usual move is:

```
new big disk ──► becomes parity
old parity   ──► becomes a data disk (after SnapRAID reconfig + re-sync)
```

So when buying, consider buying the *largest* disk you expect to own in the near
future first and use it as parity.

### 7.3 Spending priority (recommendation)

For Tier 1 data, **backup capacity (external disk + off-site) comes before
parity**. Parity protects mostly against disk failure of bulk media; backups
protect against everything else. A reasonable purchase order:

1. Backup target for Tier 1 (external disk and/or off-site/cloud).
2. Second data disk *or* parity disk, depending on how fast capacity is needed.
3. Parity once there are ≥ 2 data disks or Tier 3 media grows large.

### 7.4 Example stages

| Stage | Data | Parity | Notes |
|---|---|---|---|
| 1 | 2 TB | — | single branch pool; backups carry all protection |
| 2a | 2 + 4 TB | — | capacity first |
| 2b | 2 TB | 4 TB | protection first, no capacity gain |
| 3 | 2 + 4 TB | 8 TB | 8 TB parity covers both |
| 4 | 2 + 4 + 8 TB | 12/16 TB | new largest disk becomes parity; old 8 TB parity becomes data |

## 8. Mount and identification rules

- OMV mounts data filesystems by UUID under `/srv/dev-disk-by-uuid-<UUID>`.
  Mounts are managed in the OMV UI (**Storage → File Systems**), never by hand-editing
  `/etc/fstab`.
- Filesystem labels: `data1`, `data2`, … `parity1`, … (no capacities in labels;
  capacities go in hardware.md).
- Every disk's model/serial/UUID/label/role is recorded in [hardware.md](hardware.md).
