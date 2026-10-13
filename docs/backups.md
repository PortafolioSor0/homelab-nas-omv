# Backups

Status: **Not implemented** — designed in Phase 13 (see D-15).
Last updated: 2026-09-29

RAID ≠ backup · SnapRAID ≠ backup · mergerfs ≠ backup · snapshots ≠ backup.

## Current state

**No backups exist.** Therefore (D-10): the NAS must not be the only copy of
any Tier 1 file.

## Target (3-2-1 for Tier 1)

| Data | Copy 1 | Copy 2 (local, different device) | Copy 3 (off-site) | Versioning |
|---|---|---|---|---|
| Tier 1 (private, shared, photos) | pool | external/backup disk | cloud or remote disk, encrypted | yes, with retention |
| Tier 2 (appdata, DB dumps, OMV config) | SSD | pool `backups/` | off-site (same tool) | yes |
| Tier 3 (media) | pool | — | — | — (SnapRAID parity only) |

Requirements for the chosen tool (restic / borg / Kopia — TBD): client-side
encryption, deduplication, retention policies, integrity checks, append-only or
immutable off-site storage, failure notifications, documented and **tested** restores.

## Restore tests

| Date | What was restored | From | Result |
|---|---|---|---|
| — | — | — | — |
