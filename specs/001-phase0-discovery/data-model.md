# Data Model: Phase 0 Read-Only Discovery

These are documentation records, not database tables. Each one maps to a section of an existing
doc. The formats are in [contracts/documentation-schema.md](contracts/documentation-schema.md).

## Raw inventory snapshot

| Field | Rule |
|---|---|
| file | `discovery-raw/discovery-YYYY-MM-DD[-N].txt` on the owner's PC |
| run_method | one of the R-01 cases: B-root, B-sudo-nopw, B-sudo-pw, A |
| sections | every section header in [contracts/discovery-script.md](contracts/discovery-script.md) is present |
| tracked_in_git | MUST be false |

Relationships: it is the evidence for every Disk, Server, Network and Finding record. A second
run of the same kind is used only for the R-04 stable-section diff.

## Disk record → `docs/hardware.md` §2

| Field | Rule |
|---|---|
| role | `OS` or `data1 (planned)` or `unexpected` |
| model | exact string from `lsblk MODEL` / `smartctl` |
| serial | exact string; MUST match between `lsblk` and `smartctl` |
| capacity | as reported, in TB and TiB |
| interface | SATA / M.2 SATA / USB bridge (from `lsblk TRAN` + `lspci`) |
| by_id | `/dev/disk/by-id/…` name (ata-… form preferred) |
| fs_uuid | UUID if a filesystem exists, otherwise "none" |
| partition_state | "no partition table" / table type + partitions + FS signatures |
| mount_state | mounted paths or "not mounted" |
| health | power-on hours, reallocated, pending, offline-uncorrectable, UDMA CRC errors; for the SSD: wear/percentage used and available spare |
| dev_name | current `/dev/sdX` — **informational only** |

Validation:
- The OS record MUST have model `TOSHIBA KSG60ZMV256G` and be marked "NEVER a data disk".
- A disk count different from 2, or a missing 2 TB disk, sets `role = unexpected` and blocks
  Stage 5 (spec edge case).

## Server record → `docs/hardware.md` §1

The fields are OS/Debian release, OMV version, kernel, installed OMV plugins, omv-extras
(yes/no), board/BIOS, CPU model, iGPU and `/dev/dri` (yes/no), RAM size, ECC (yes/no/unknown),
NIC model and speed, and ATA port count.

Anything software can't see (free bays, PSU, UPS) is filled from the owner's physical
inspection or written as "unknown — reason".

Validation: never record a MAC address. NIC is recorded as model and speed only.

## Network / exposure record → `docs/network.md`

The fields are IP addressing mode (DHCP/static), the NAS's LAN IP (private range only),
gateway, DNS, listening services (port/proto/process), SSH effective policy
(`permitrootlogin`, `passwordauthentication`, `pubkeyauthentication`,
`kbdinteractiveauthentication`, `permitemptypasswords`, allow users/groups), firewall present
(yes/no and rule count), router model, port forwards, UPnP/NAT-PMP, DHCP reservation, and
guest/IoT network.

## Finding → `docs/phase-0-discovery.md` §5

| Field | Rule |
|---|---|
| id | `F-01`, `F-02`, … |
| observation | a fact quoted from the raw output |
| severity | High / Medium / Low / Info |
| addressed_in | phase number (for example 1, 2, 3, 11), or "decision D-xx" |

Findings are never fixed in Phase 0 (FR-011).

## Decision record → `docs/decisions.md`

| Field | Rule |
|---|---|
| id | D-01 … D-18 |
| status | OPEN → PROPOSED → DECIDED |
| decided_on | ISO date, required when the status is DECIDED |
| choice | the chosen option |
| evidence | reference to disk/server/finding facts |
| approved_by | owner, with an explicit statement in the session |

State transitions:
- `OPEN → PROPOSED`: the assistant or owner writes a recommendation.
- `PROPOSED → DECIDED`: **only** on explicit owner approval (R-06).
- D-06 `→ DECIDED` is additionally blocked if the 2 TB disk shows any partition table or FS
  signature (R-07).
- `DECIDED → PROPOSED` (reopen) is allowed only with a CHANGELOG note.

## Phase 0 status

`Documentation done; on-server discovery NOT yet run` → `Inventory captured` →
`Documented` → `Decisions made` → `Complete (awaiting Phase 1 approval)`.
`Blocked: D-06` can come after `Documented`.
