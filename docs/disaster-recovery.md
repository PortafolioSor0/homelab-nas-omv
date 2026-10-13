# Disaster recovery

Status: **Skeleton** — filled in as components are implemented.
Last updated: 2026-09-29

## Scenarios to document

| Scenario | Procedure outline | Status |
|---|---|---|
| OS SSD dies | Reinstall OMV 8 → reapply config from this repo/notes → re-mount data disks by UUID → restore appdata/DBs from backup → redeploy compose stacks | TBD |
| Single data disk dies (no parity yet) | Restore Tier 1 from backup; re-acquire Tier 3 | TBD |
| Single data disk dies (with SnapRAID) | Replace disk → `snapraid fix` → verify → sync | TBD (Phase 14) |
| Ransomware / mass deletion on shares | Stop SMB, do **not** run `snapraid sync`, restore from versioned off-site backup | TBD |
| Immich broken / DB lost | Originals intact on disk; restore DB dump; worst case re-import library | TBD (Phase 9) |
| Whole server lost (fire/theft) | New hardware → restore Tier 1 + Tier 2 from off-site | TBD |
| Lost admin access (web UI / SSH) | Physical console → `omv-firstaid` | TBD (Phase 1) |

## Critical recovery information (stored OUTSIDE this repo)

- Password manager: admin credentials, backup repository passwords, LUKS keys (if D-01 = B/C)
- Offline copy of the above (paper / encrypted USB) in a known location
- Latest OMV `config.xml` export (encrypted, off-repo)
