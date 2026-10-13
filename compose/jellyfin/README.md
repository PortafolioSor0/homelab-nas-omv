# jellyfin

Media server for Tier 3 media (`media/` on `data1`). Phase 8. LAN only (Tailscale in Phase 11).

| Item | Value |
|---|---|
| Image | `jellyfin/jellyfin:12.2.20261005-225228` (pinned) |
| Runs as | `svc-jellyfin` UID/GID 2001 (no login, no password) + `render` group for `/dev/dri/renderD128` |
| Port | `192.168.10.250:8096/tcp` (HTTP, LAN only). No DLNA / auto-discovery ports |
| Hardware transcoding | Intel UHD 730 via VA-API/QSV on `renderD128` only (D-17); no `privileged` |

## Mounts

| Host path | Container | Mode | Notes |
|---|---|---|---|
| `/appdata/data/jellyfin/config` | `/config` | rw | SSD; config, users, metadata DB. Tier 2 |
| `/appdata/data/jellyfin/cache` | `/cache` | rw | SSD; regenerable (transcodes, images). Not backed up |
| `/srv/dev-disk-by-uuid-aaaaaaaa-…/media` | `/media` | **ro** | `data1`; libraries `/media/movies`, `/media/tv`, `/media/music` |

All binds use `create_host_path: false`, so a missing path (for example `data1` not mounted) stops
the container instead of creating an empty directory on the SSD.

## Access

- Filesystem: `svc-jellyfin` has an ACL entry `r-x` (plus a default ACL) on `media` and its
  subfolders. It has no write access anywhere on `data1`.
- App accounts (not Linux users): an admin account, plus `alex` and `sam` as normal users.
  Passwords live in the password manager.

## Backup and restore

- Backup: `/appdata/data/jellyfin/config` (Tier 2) through the compose plugin backup → `backups/` and,
  from Phase 13, off-site. The cache is excluded.
- Restore: stop the stack, restore `config/` with owner 2001:2001, then start the stack. The media
  itself is Tier 3 (re-obtainable).
