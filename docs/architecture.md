# Architecture

Status: **Draft (Phase 0)** — nothing below is implemented yet unless stated.
Last updated: 2026-09-29

## 1. Purpose

A single home server (`nas.internal`, OpenMediaVault 8) that grows into:

- a NAS for personal, family, university/work and project data
- a media server (Jellyfin)
- a photo platform (Immich, pending evaluation)
- private per-person storage (owner, relative, future family)
- a Docker host for self-hosted services
- securely reachable from outside the home **without** exposing admin surfaces

## 2. Design principles

| # | Principle | Consequence |
|---|---|---|
| P1 | Data safety over convenience | Destructive operations are gated, documented, reversible where possible |
| P2 | Separate data by **nature**, not by application | Bulk data, app state, databases and backups live in different places with different protection |
| P3 | Protection proportional to value | Tier 1 gets versioned off-site backups; Tier 3 gets at most parity |
| P4 | Heterogeneous, incremental disks | One filesystem per disk + mergerfs pool + SnapRAID parity (no classic RAID) |
| P5 | Least privilege everywhere | Per-user private areas, per-service accounts, read-only mounts by default |
| P6 | No public admin surface | OMV UI, SSH, SMB, NFS, DBs, Docker API reachable only via LAN / VPN |
| P7 | Stable paths | Applications and shares reference a pool path that does not change when disks are added |
| P8 | Everything reconstructable from this repo | Compose files, decisions, procedures and change log are versioned here |

## 3. Data classification

| Tier | Examples | Protection target |
|---|---|---|
| **Tier 1 – Irreplaceable** | personal photos/videos, documents, university/work files, source code, digital products, personal archives | Parity (disk failure) **+ local backup + off-site versioned backup** (3-2-1) |
| **Tier 2 – Important** | OMV config, Compose files, app configs (Jellyfin, Immich…), databases | Scheduled dumps/backups to HDD **+ off-site**, documented restore procedure |
| **Tier 3 – Replaceable** | movies, TV, music that can be re-acquired | SnapRAID parity only (optional). **No** paid backup capacity |

Rule: **the top-level folder a file lives in determines its tier**. This is what
makes backup selection simple and hard to get wrong. Personal videos are Tier 1,
so they belong with photos — *not* under `media/`, even though they are video.

## 4. Logical architecture

```
                         ┌──────────────── Remote devices ────────────────┐
                         │  phone / laptop (owner)   laptop (relative)      │
                         └───────────────────┬────────────────────────────┘
                                             │ WireGuard (Tailscale overlay)
                                             │ no router port-forwards
┌────────────────────────── Home LAN ────────┼────────────────────────────────────┐
│                                            ▼                                    │
│   ┌────────────────────────── nas.internal (OMV 8) ─────────────────────────┐   │
│   │                                                                         │   │
│   │  Admin plane (LAN/VPN, admins only)   Data plane (per-user)             │   │
│   │   • OMV web UI (HTTPS)                 • SMB shares (per-user/private)  │   │
│   │   • SSH (keys only)                    • Jellyfin (app accounts only)   │   │
│   │                                        • Immich (app accounts only)     │   │
│   │                                                                         │   │
│   │  ┌── SSD 256 GB (OS disk) ─────────┐   ┌── HDD pool (mergerfs) ────────┐ │   │
│   │  │ OMV / Debian                    │   │ Tier 1: private-*, photos/,   │ │   │
│   │  │ Docker engine + images          │   │         shared/               │ │   │
│   │  │ Compose definitions             │   │ Tier 3: media/                │ │   │
│   │  │ App config + databases (Tier 2) │──►│ backups/ (copies of SSD state)│ │   │
│   │  └─────────────────────────────────┘   └───────────────┬───────────────┘ │   │
│   │                                                        │ SnapRAID parity  │   │
│   │                                                        ▼ (future)         │   │
│   │                                               parity disk ≥ largest data  │   │
│   └─────────────────────────────────────────────────────────┬───────────────┘   │
└─────────────────────────────────────────────────────────────┼───────────────────┘
                                                              │ encrypted, versioned
                                                              ▼
                                                   Off-site backup (Tier 1 + 2)
```

### 4.1 Where things live (proposed)

| Category | Location | Why |
|---|---|---|
| OS | SSD | Given |
| Docker engine data (`/var/lib/docker`: images, container layers) | SSD | Fast, disposable (re-pullable) |
| Compose definitions | SSD **and** this Git repo | Git is the source of truth |
| App config / app state (Jellyfin metadata, Immich config) | SSD | Small, random I/O, frequently changing — bad fit for SnapRAID and for HDD latency |
| Databases (Immich Postgres, etc.) | SSD, local filesystem only | Databases must not live on FUSE (mergerfs) or network storage; SSD latency |
| Regenerable caches (thumbnails, transcodes, trickplay) | SSD if capacity allows, else a non-SnapRAID HDD path | Churn would constantly invalidate parity |
| Bulk data (Tier 1 + Tier 3) | HDD pool | Capacity, parity-friendly (mostly static) |
| Backups of SSD state (DB dumps, app config, OMV config) | HDD pool `backups/` + off-site | Different physical device from the source |
| Backups of Tier 1 bulk data | **Separate device + off-site**, never the same pool | A copy on the same disks is not a backup |

**Consequence:** the single OS SSD becomes a single point of failure for all
application state. That is acceptable **only** if Tier 2 data is backed up daily
to the HDD and off-site, and the restore procedure is tested (Phase 13). A
second SSD for app data is a reasonable later upgrade (see decisions D-11).

## 5. Identity model (summary — details in users-and-permissions.md)

Three separate kinds of identities that must never be conflated:

1. **Linux/OMV accounts** — people who get filesystem access (SMB) or admin access.
2. **Application accounts** — Jellyfin/Immich logins. Not Linux users. No SMB, no SSH.
3. **Service accounts** — dedicated UIDs that containers run as. No login shell, no password.

Admin rights are held by a dedicated admin account, not by the account used for
day-to-day file access.

## 6. Network exposure model

| Service | LAN | VPN (Tailscale) | Public Internet |
|---|---|---|---|
| OMV web UI | admins | admins | **never** |
| SSH | admins (keys) | admins (keys) | **never** |
| SMB | per-user | per-user (ACL-restricted) | **never** |
| Jellyfin | yes | yes | only if later explicitly justified + approved, via reverse proxy |
| Immich | yes | yes | same as Jellyfin |
| Docker API | **no** (unix socket only) | no | **never** |
| Databases | container network only | no | **never** |

## 7. Evolution stages

| Stage | Disks | Protection |
|---|---|---|
| Now | SSD (OS) + 2 TB data | none — Tier 1 data must still exist elsewhere |
| After Phase 13 | + backup target(s) | 3-2-1 for Tier 1 |
| Stage 2+ | + more data disks | mergerfs grows, paths unchanged |
| Parity stage | + parity disk ≥ largest data disk | SnapRAID against single-disk failure |

See [storage.md](storage.md) and [roadmap.md](roadmap.md).

## 8. Related documents

- [storage.md](storage.md) · [security.md](security.md) · [hardware.md](hardware.md)
- [roadmap.md](roadmap.md) · [decisions.md](decisions.md)
- [users-and-permissions.md](users-and-permissions.md) · [network.md](network.md)
- [backups.md](backups.md) · [disaster-recovery.md](disaster-recovery.md)
