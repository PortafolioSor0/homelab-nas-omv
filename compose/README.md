# compose/

One directory per Docker Compose stack (e.g. `jellyfin/`, `immich/`), created
from Phase 8 onward. Docker and the OMV compose plugin were set up in Phase 7.

## Where stacks live on the NAS

- The OMV compose plugin (**Services → Compose**) manages the stacks. It stores each
  one under `/appdata/<stack>/` on the OS SSD (`appdata` shared folder, D-11 = A).
- This repo is the **source of truth** for the YAML. Paste it into the plugin and keep
  both copies identical.
- Plugin backups go to the `backups` shared folder on `data1`.
- Docker images/layers live in `/var/lib/docker` (SSD). They can be re-pulled and are
  never backed up.

## Each stack contains

- `compose.yaml`: the stack definition (rules below).
- `.env.example`: every variable, with **placeholder** values.
- `README.md`: purpose, mounts (host path → container path, rw/ro), UID/GID, ports,
  and backup and restore notes.

Real `.env` files live only on the NAS (mode 600) and are git-ignored.

## Rules for every stack (security.md T7/T8)

1. **Pinned images:** use an explicit version tag (never `latest`), and update
   deliberately.
2. **Non-root:** set `user: "<uid>:<gid>"` to a service account in the 2000–2099
   range (users-and-permissions.md §3). Create the account in the same phase as the
   app and record it there.
3. **No `privileged: true`**, no `network_mode: host` unless justified in the stack
   README, and never mount `/var/run/docker.sock`.
4. **Minimal mounts:** app state goes under `/appdata/data/<stack>/` (SSD), owned by the
   service account. `/appdata/<stack>/` belongs to the plugin (compose file + `.env`, root 600). Media and
   photo libraries are mounted `:ro` unless the app must write to them. Never mount
   a whole disk or `/srv/...` root.
5. **Ports:** publish only what a client needs, and bind to the LAN IP
   (`192.168.10.250:<port>:<port>`), never implicitly to `0.0.0.0`. Docker-published
   ports bypass any host firewall. Nothing is ever port-forwarded to the internet
   (remote access = Tailscale, Phase 11).
6. **Databases** go on the SSD only (never `data1`/mergerfs), with a scheduled dump
   to `backups/db-dumps/`.
7. **No secrets in Git:** use `.env` on the NAS, and `.env.example` with
   placeholders here.
8. **Never** `docker system prune` / `docker volume prune` / `docker volume rm`
   without the approval gate in CLAUDE.md.
