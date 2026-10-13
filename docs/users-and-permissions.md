# Users and permissions

Status: **Draft (Phase 0)** — nothing created yet. Implemented in Phase 5.
Last updated: 2026-09-29

## 1. Identity types (never mixed)

| Type | Examples | Filesystem access | Login |
|---|---|---|---|
| Admin account | `owner-admin` (created Phase 1.6) | via sudo only | SSH (key), OMV web UI |
| Data accounts | `owner`, `relative` | own private area + explicitly shared areas, via SMB | SMB only (no shell) |
| Service accounts | `svc-jellyfin`, `svc-immich` | only mounted paths, read-only where possible | none (no shell, no password) |
| Application accounts | Jellyfin/Immich users | **none** | only inside that app |

A Jellyfin or Immich user is **never** a Linux account.

## 2. Access matrix (see storage.md §4.2; D-09 decided 2026-10-03)

Shared-folder names as created in Phase 4 (flat layout, D-08). `alex` = owner, `sam` = relative.

| Area | alex | sam | family group | svc-jellyfin | svc-immich |
|---|---|---|---|---|---|
| `private-alex` | rw | — | — | — | — |
| `private-sam` | — | rw | — | — | — |
| `shared-family` | rw | rw | rw | — | — |
| `photos` | — (via Immich app account; admin via sudo) | — (via Immich) | — | — | rw |
| `media/*` | rw (manager) | — (watches via Jellyfin app account) | — | **ro** (Phase 8) | — |
| `backups/` | — (admin only) | — | — | — | — |

The admin can reach everything via sudo for maintenance; that does not imply SMB access.

### 2.1 Implemented on disk (Phase 5.3, 2026-10-03)

`data1` root = `/srv/dev-disk-by-uuid-aaaaaaaa-1111-4222-8333-444444444444` (`root:root` 755,
not shared).

| Path | Owner:group | Mode | ACL |
|---|---|---|---|
| `private-alex` | `alex:users` | `drwx--S---` (2700) | — |
| `private-sam` | `sam:users` | `drwx--S---` (2700) | — |
| `shared-family` | `root:family` | `drwxrws---` (2770) | default `user::rwx,group::rwx,other::---` (new files are group-editable) |
| `photos` | `root:users` | `drwx--S---` (2700) | — (Immich service account in Phase 9) |
| `media` | `alex:users` | `drwx--S---` (2700) | `user:svc-jellyfin:r-x` + default `user:svc-jellyfin:r-x`, mask `r-x` (Phase 8.2) |
| `media/{movies,tv,music}` | `alex:users` | `drwx--S---` (2700) | same as `media` (Phase 8.2) |
| `backups` | `root:users` | `drwx--S---` (2700) | — |

The `users` group has no permission bits anywhere (the group is only the primary group of every
account).

**Cross-user test (5.4)**, using `sudo -u <user> test -r -a -w -a -x` (no files created). RW =
read+write+enter, — = denied:

| | private-alex | private-sam | shared-family | photos | media | backups |
|---|---|---|---|---|---|---|
| alex | RW | — | RW | — | RW | — |
| sam | — | RW | RW | — | — | — |
| owner-admin (without sudo) | — | — | — | — | — | — |

To repeat the test after any permission change, use the loop in CHANGELOG 2026-10-03 (Phase 5.3–5.4).
Note: glob `"$D"/media/*` run as owner-admin does not expand (owner-admin cannot list `media`), so
use `sudo ls` for subfolders.

## 3. UID/GID plan (proposed, D-09)

| Range | Use |
|---|---|
| 0–999 | Debian system accounts |
| 1000–1999 | Human accounts (created by OMV) |
| 2000–2099 | Service accounts for containers (fixed numbers, recorded below) |

Why it matters: containers write files with numeric UIDs. If a container runs as
UID 2001, files it creates are owned by 2001 on disk; SMB users see them only
through group membership/ACLs. Fixed, documented numbers keep ownership stable
across rebuilds.

| Account | UID | Primary GID | Supplementary groups | Created |
|---|---|---|---|---|
| `owner-admin` | 1000 | 100 (`users`) | `sudo` (27), `_ssh` (102) | 2026-09-29 (Phase 1.6) |
| `alex` | 1001 | 100 (`users`) | `family` (1000) | 2026-10-03 (Phase 5.1). Shell `/usr/sbin/nologin`, "Disallow account modification" on |
| `sam` | 1002 | 100 (`users`) | `family` (1000) | 2026-10-03 (Phase 5.1). Shell `/usr/sbin/nologin`, "Disallow account modification" on |
| `svc-jellyfin` | 2001 | 2001 (`svc-jellyfin`) | — (container adds `render` 992 via `group_add`) | 2026-10-06 (Phase 8.1). CLI `useradd`, no home (`/nonexistent`), nologin, password locked |

| Group | GID | Members | Created |
|---|---|---|---|
| `family` | 1000 | `alex`, `sam` | 2026-10-03 (Phase 5.2) |
| `svc-jellyfin` | 2001 | — (primary group of `svc-jellyfin`) | 2026-10-06 (Phase 8.1) |

Note: OMV records `/home/alex` and `/home/sam` as home paths, but they do not exist (no
user-home shared folder). This is harmless for nologin data accounts.

`owner-admin` logs in over SSH with two ed25519 keys (OMV **Users → owner-admin → SSH public keys**):
`SHA256:EXAMPLEkeyOneAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA` (first operator PC, Phase 1.6) and
`SHA256:EXAMPLEkeyTwoBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB` (desktop PC, comment `pc-alex-nas`, added by
the owner 2026-10-03). Each private key stays only on its own PC. Its shell is `/usr/bin/bash`. Like every
OMV-created account, its primary group is `users` (GID 100). **Phase 4/5 note:** never grant share
access through the `users` group. Otherwise the admin account would get data access through
the filesystem. Use the dedicated groups from D-09.

## 4. Rules

- No `777` / world-writable directories.
- No recursive `chmod`/`chown` without showing the exact path and getting approval.
- Prefer OMV's shared-folder permission/ACL UI for share-level permissions.
- After every permission change: test that the intended user **can** and that a
  different user **cannot** access the path.
