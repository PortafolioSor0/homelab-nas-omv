# Changelog

All infrastructure changes to `nas.internal`, newest first.
Format: [docs/templates/change-record.md](docs/templates/change-record.md).

## 2026-10-06 — Phase 8.0–8.4: svc-jellyfin, media ACL, Jellyfin container up

- **Phase:** 8 (steps 8.0–8.4)
- **Objective:** Jellyfin running as a non-root service account with read-only media (D-17 = A).
- **Previous state (8.0, read-only):** `media/{movies,tv,music}` empty; `render` GID 992, `video` 44;
  `/dev/dri/card0` (video), `renderD128` (render); UID/GID 2001 free; TZ `America/Chicago`.
- **Change performed:** Owner approval: "R, sí 8.1–8.3" (D-17 = A, plan, steps) and "sí, 8.4".
  (8.1) `groupadd -g 2001 svc-jellyfin`; `useradd -u 2001 -g 2001 -M -d /nonexistent -s
  /usr/sbin/nologin -c "Jellyfin service" svc-jellyfin`. (8.2) `setfacl -m
  u:svc-jellyfin:rx,d:u:svc-jellyfin:rx` on `media`, `media/movies`, `media/tv`, `media/music`
  (non-recursive; folders were empty). (8.3) `install -d` `/appdata/data` (root 0700) and
  `/appdata/data/jellyfin/{,config,cache}` (2001:2001 0750). (8.4) OMV **Services → Compose →
  Files**: stack `jellyfin` = `compose/jellyfin/compose.yaml`, env `RENDER_GID=992`,
  `TZ=America/Chicago` → Up.
- **Affected devices/paths:** `/etc/passwd`, `/etc/group` (svc-jellyfin); ACLs on `data1:/media*`;
  `/appdata/data/jellyfin`; image `jellyfin/jellyfin:12.2.20261005-225228`.
- **Approval:** Owner, in session, 2026-10-06.
- **Result / verification:** `id` = 2001/2001, `passwd -S` = `L`. `getfacl media`:
  `user:svc-jellyfin:r-x`, `mask::r-x`, default ACL same. `sudo -u svc-jellyfin test`: reads all
  four media folders, cannot write; no access to `private-alex`, `private-sam`, `shared-family`,
  `photos`, `backups`. Container `Up (healthy)`; `user=2001:2001`, `groups=[992]`,
  `caps_drop=[ALL]`, device `/dev/dri/renderD128` only; listener `192.168.10.250:8096` only
  (`docker-proxy`); ffmpeg 8.1.3 lists `qsv`/`vaapi` hwaccels and `h264_qsv`/`hevc_qsv`/`av1_qsv`
  encoders; `touch /media/prueba` → `Read-only file system`. Log warning `WebRootPath was not
  found: /wwwroot` (to check in 8.5 that the web UI loads).
- **Rollback:** Compose **Down** + delete stack; `setfacl -x u:svc-jellyfin,d:u:svc-jellyfin` on
  the four folders; `userdel svc-jellyfin`; `rmdir` the empty `/appdata/data/jellyfin` dirs.
- **Docs updated:** CHANGELOG.md, docs/users-and-permissions.md, docs/network.md,
  docs/decisions.md, docs/roadmap.md.

## 2026-10-06 — Phase 7.7: Docker smoke test; Phase 7 closed

- **Phase:** 7 (steps 7.7, 7.8, phase close)
- **Objective:** Prove the engine works end to end, then close Phase 7.
- **Previous state:** Docker + compose plugin configured (7.3–7.5); no images or containers.
- **Change performed:** `sudo docker run --rm hello-world` (pulled `hello-world:latest`, digest
  `sha256:5e230903…`), then `sudo docker image rm hello-world` (that image only; no prune).
  Repo: stack rules written in `compose/README.md` (7.8).
- **Affected devices/paths:** `/var/lib/docker` (temporary image, removed).
- **Approval:** Owner, in session: "sí, 7.7", 2026-10-06.
- **Result / verification:** "Hello from Docker!"; image untagged and deleted; `docker ps -a` and
  `docker images` empty. Phase 7 exit criteria: Docker via OMV compose plugin ✓; appdata on SSD ✓
  (`/appdata`, D-11 = A); compose files in Git + `.env.example` convention ✓ (`compose/README.md`);
  non-root policy ✓ (same file). No ports published, no `docker` group members.
- **Rollback:** None needed.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md, README.md, CLAUDE.md, compose/README.md.

## 2026-10-06 — Phase 7.5: Compose plugin settings

- **Phase:** 7 (step 7.5)
- **Objective:** Point the compose plugin at `appdata` (SSD) and `backups` (data1).
- **Previous state:** Plugin installed with no shared folders set.
- **Change performed:** OMV UI → **Services → Compose → Settings**: Compose Files = `appdata`
  (owner/group `root`, Administrator RW / Users none / Others none); Data = None; Backup = `backups`
  (data1), Max Size 1 GB, backend rsync; Docker storage `/var/lib/docker` (no shared folder), log
  max 50 MB, Live restore off, Start delay 0; Overrides default (Create symlinks on). Save/Apply.
- **Affected devices/paths:** OMV config `conf.service.compose`; `/appdata/global.env` created by the
  plugin (`root:root` 600, effectively empty).
- **Approval:** Owner, in session: "sí, 7.5", 2026-10-06.
- **Result / verification:** `omv-confdbadm read conf.service.compose` matches the above
  (`backupsharedfolderref` = `backups`, `datasharedfolderref` empty, `fileperms 600`);
  `daemon.json` unchanged. **To revisit:** backup Max Size 1 GB (Immich DB, Phase 9/13); Start delay
  vs `data1` mount timing (Phase 8).
- **Rollback:** Clear the fields in Compose Settings → Save.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md.

## 2026-10-06 — Phase 7.4: `appdata` shared folder on the OS SSD

- **Phase:** 7 (step 7.4)
- **Objective:** Home for compose files and app config/DBs on the SSD (D-11 = A).
- **Previous state:** No shared folder on the root filesystem.
- **Change performed:** OMV UI → **Storage → Shared Folders → Create**: name `appdata`, file system
  `/` (root, offered by `sharerootfs`), relative path `appdata/`, Administrator RW / Users none /
  Others none.
- **Affected devices/paths:** `/appdata` on the OS SSD root fs (`sdb2`, ext4
  `bbbbbbbb-1111-4222-8333-444444444444`). The OS disk was not repartitioned.
- **Approval:** Owner, in session: "sí, 7.4", 2026-10-06.
- **Result / verification:** `drwx--S--- root:users /appdata` (2700, no access for group/others);
  `/` 221G, 3.2G used, 207G free.
- **Rollback:** Delete the (empty) shared folder in OMV.
- **Docs updated:** CHANGELOG.md, docs/storage.md, docs/roadmap.md.

## 2026-10-06 — Phase 7.3: openmediavault-compose installed (Docker installed with it)

- **Phase:** 7 (step 7.3)
- **Objective:** OMV-managed Docker Compose (plugin) + `sharerootfs` for `appdata` on the OS SSD (D-11 = A).
- **Previous state:** omv-extras + Docker apt repo present; no Docker.
- **Change performed:** OMV UI → **System → Plugins** → `openmediavault-compose` → Install.
- **Affected devices/paths:** packages `openmediavault-compose` 8.2.0, `openmediavault-sharerootfs`
  8.0.1-1 (dependency; never uninstall it). **Deviation from plan:** the install also pulled in
  Docker Engine (planned for 7.5): Docker 29.8.2, Docker Compose v5.6.0, service `docker` active.
  `/etc/docker/daemon.json` written by the plugin: `data-root /var/lib/docker` (OS SSD, as D-11),
  `json-file` logs `max-size 50m`, `max-file 3`, `storage-driver overlay2`.
- **Approval:** Owner, in session: "sí, 7.3", 2026-10-06.
- **Result / verification (7.6 checks done early, read-only):** group `docker` (GID 982) has **no
  members**; no TCP listener on 2375/2376 (API on the unix socket only); `docker ps -a` empty;
  `docker0` 172.17.0.1/16, DOWN (no containers); no overlap with the LAN 192.168.10.0/24.
- **Rollback:** Uninstall the plugin in **System → Plugins**; `sudo apt-get purge docker-ce
  docker-ce-cli containerd.io docker-compose-plugin` (nothing stored in Docker yet).
- **Docs updated:** CHANGELOG.md, docs/roadmap.md, CLAUDE.md.

## 2026-10-06 — Phase 7.2: Docker apt repository enabled

- **Phase:** 7 (step 7.2)
- **Objective:** Make Docker's official packages (`docker-ce`, `docker-compose-plugin`) available
  to the compose plugin.
- **Previous state:** apt sources = Debian + four `openmediavault*` lists + `omvextras.sources`.
- **Change performed:** OMV UI → **System → OMV-Extras** → Docker repo enabled → Save/Apply.
- **Affected devices/paths:** `/etc/apt/sources.list.d/omvdocker.sources` (new, deb822):
  `URIs: https://download.docker.com/linux/debian`, `Signed-By: /usr/share/keyrings/docker.gpg`.
- **Approval:** Owner, in session: "sí, 7.2", 2026-10-06.
- **Result / verification:** `apt-get update` → `Hit https://download.docker.com/linux/debian trixie
  InRelease`, no `E:`/`W:` lines. Docker itself not installed yet (7.5).
- **Rollback:** Disable Docker repo in **System → OMV-Extras** → Save.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md, CLAUDE.md.

## 2026-10-03 — Phase 7.1: omv-extras installed

- **Phase:** 7 (step 7.1)
- **Objective:** Add the omv-extras plugin source, needed for `openmediavault-compose` (D-11 = A).
- **Previous state:** apt sources = Debian `trixie` + `trixie-updates` in `/etc/apt/sources.list`
  (one-line format) + four `openmediavault*` lists; no omv-extras.
- **Change performed:** Official installer downloaded to `/tmp/omvextras-install.sh` (2124 bytes,
  87 lines, sha256 `c28343a4f9087e354916c81da45f816667dfdd3414d729f0e33a21f74268de59`) and reviewed
  in session. Its "add missing Debian repo" lines were a no-op (both repos already matched). Run
  with `cd /tmp && sha256sum -c … && sudo bash /tmp/omvextras-install.sh`: installs `gnupg` and
  `openmediavault-omvextrasorg` (`.deb` over https from the omv-extras GitHub; no package signature
  check, which is the documented method).
- **Affected devices/paths:** `/etc/apt/sources.list.d/omvextras.sources` (new, deb822 format);
  packages `gnupg`, `openmediavault-omvextrasorg` 8.0.3.
- **Approval:** Owner, in session: "sí, instala omv-extras", 2026-10-03.
- **Result / verification:** `dpkg -l` shows `ii openmediavault-omvextrasorg 8.0.3`;
  `sources.list.d` has `omvextras.sources`; `apt-get update` finished cleanly. No disk, data, SMB or
  SSH change.
- **Rollback:** `sudo apt-get purge openmediavault-omvextrasorg` and remove
  `/etc/apt/sources.list.d/omvextras.sources`.
- **Docs updated:** CHANGELOG.md.

## 2026-10-03 — Second SSH key for owner-admin; Phase 7.0 pre-check

- **Phase:** 7 (step 7.0, read-only) + access change made by the owner
- **Objective:** Let the desktop PC reach the NAS over SSH, and record the baseline before Docker.
- **Previous state:** Only key `SHA256:EXAMPLEkeyOne…` authorized for `owner-admin`; the desktop PC had no
  `Host nas` entry and its key was refused (`Permission denied (publickey)`).
- **Change performed:** The owner added the desktop PC's **public** key (`SHA256:EXAMPLEkeyTwo…`, comment
  `pc-alex-nas`) to `owner-admin` in the OMV UI and a `Host nas` entry on that PC. No server change
  by Claude. 7.0 (read-only): `dpkg -l openmediavault`, `/etc/debian_version`, `sources.list.d`,
  `df -h /`, `command -v docker`, `getent group docker`, `ss -tlnp`, `ssh-keygen -lf` of the OMV
  authorized-keys file.
- **Affected devices/paths:** `/var/lib/openmediavault/ssh/authorized_keys/owner-admin` (OMV-managed).
- **Approval:** Owner's own action, 2026-10-03.
- **Result / verification:** Both fingerprints listed for `owner-admin`; `ssh nas` works from the
  desktop. Host key unchanged (`SHA256:EXAMPLEhost…`, same as the old `192.168.10.108` entry). Baseline:
  OMV 8.5.9-1, Debian 13.7; apt sources are only the four `openmediavault*` lists (no omv-extras);
  `/` 221G, 2.7G used, 207G free; Docker not installed, no `docker` group. Listeners match
  network.md, plus 5357 (`wsdd`, LAN IP only) and 25 (Postfix, localhost) now documented; 80/443
  listen on IPv4 only.
- **Rollback:** Remove the key in **Users → owner-admin → SSH public keys**.
- **Docs updated:** CHANGELOG.md, docs/users-and-permissions.md, docs/network.md.

## 2026-10-03 — Phase 6.4: client tests; Phase 6 closed

- **Phase:** 6 (steps 6.4, 6.5, phase close)
- **Objective:** Prove per-user visibility and access from real clients.
- **Previous state:** SMB configured (6.1–6.3).
- **Change performed:** No server changes. Client tests: Windows PC (192.168.10.123) as `alex` on
  `\\nas.local`; the owner's iPhone (192.168.10.177) as `alex` via Files → `smb://nas.local`; the
  same Windows PC as `sam` on `\\192.168.10.250` (a different server name, so separate
  credentials; not remembered, removed afterwards with `net use … /delete`). Test files were created
  by the owner through SMB (`prueba-alex.txt.txt` in `private-alex` and in `shared-family`). They
  are the owner's to keep or delete.
- **Affected devices/paths:** None on the server beyond the test files and the `.recycle` folder
  that Samba created in `private-alex`.
- **Approval:** Owner, in session, 2026-10-03.
- **Result / verification:** The owner reports all tests passed: alex sees only `private-alex`,
  `shared-family`, `media`; sam sees only `private-sam`, `shared-family`; sam was denied
  `private-alex`; sam edited alex's file in `shared-family`. `smbstatus -b` shows sessions for alex
  and sam, all **SMB3_11**, signing AES-128-GMAC, encryption off (as configured). On disk:
  `shared-family/prueba-alex.txt.txt` is `alex:family -rw-rw----` and grew to 6 bytes after
  sam's edit (default ACL works). `private-alex/.recycle` is `drwxrws---` (0770 applied, not 0777).
  Phase 6 exit criteria: per-user shares ✓, SMB3 min ✓, no guest ✓, other users' private shares
  not browsable (ABE) ✓, tested from clients ✓. **Pending (non-blocking):** set up sam's iPhone
  (Files → `smb://nas.local` → user `sam`) when the owner is with her. No server change is needed.
- **Rollback:** n/a.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md, README.md, CLAUDE.md.

## 2026-10-03 — Phase 6.1–6.3: SMB enabled, privileges, 4 shares

- **Phase:** 6 (steps 6.1–6.3)
- **Objective:** LAN SMB access for `private-alex`, `private-sam`, `shared-family` and `media`
  (`photos` and `backups` are never shared).
- **Previous state:** SMB disabled. No shared-folder privileges.
- **Change performed:**
  - 6.1, OMV UI → Services → SMB/CIFS → Settings: enabled, WORKGROUP, **Minimum protocol
    SMB3**, NetBIOS off, WINS off, home directories off, sendfile/async I/O default on. Extra
    options: `smb ports = 445`.
  - 6.2, Storage → Shared Folders → Permissions: `private-alex` alex RW, sam/owner-admin no
    access; `private-sam` sam RW, alex/owner-admin no access; `shared-family` group family RW,
    owner-admin no access; `media` alex RW, sam/owner-admin no access. `family` was left unset on
    the private shares and users were left unset on `shared-family`, because "No access" (`invalid
    users`) would override group membership.
  - 6.3, Services → SMB/CIFS → Shares, one per folder: Public No, Read-only off, Browseable,
    macOS compatibility (catia/fruit/streams_xattr), Inherit ACLs on, Inherit permissions off, Hide
    dot files, Follow symlinks on with **Wide links off**, Extended attributes on, Transport
    encryption off (iOS compatibility unverified; LAN-only now, Tailscale later). Extra options:
    `access based share enum = yes`. Recycle bin (unrestricted size, 30-day retention) on the
    private and shared-family shares, plus Extra option `recycle:directory_mode = 0770` (OMV's
    default is 0777). No recycle bin on `media`.
- **Affected devices/paths:** Samba configuration (`/etc/samba/smb.conf`, OMV-generated); OMV
  shared-folder privileges. Port 445/tcp now open on the LAN.
- **Approval:** Owner, Phase 6 approved in session, 2026-10-03.
- **Result / verification (read-only, as owner-admin, no sudo):** `testparm -s` shows
  `server min protocol = SMB3_00` and `disable netbios = Yes`, ABE on all 4 shares, no `guest ok`.
  `valid users`/`write list`/`invalid users` match the table above (e.g. `[shared-family] valid
  users = @family`, `invalid users = owner-admin`). `smb.conf` has `smb ports = 445` (line 41). In
  each recycle share, our `recycle:directory_mode = 0770` comes **after** OMV's `0777`, and Samba
  uses the last value. `ss -tln` shows only 445 (139 closed). Note: the first attempt at the Extra
  options was not saved/applied, so after any OMV change check `/etc/samba/smb.conf` with grep.
- **Rollback:** Disable SMB in Services → SMB/CIFS → Settings, or delete individual shares.
- **Docs updated:** CHANGELOG.md, docs/network.md.

## 2026-10-03 — Phase 5.3–5.4: folder ownership/ACLs and cross-user test; Phase 5 closed

- **Phase:** 5 (steps 5.3, 5.4, 5.5, phase close)
- **Objective:** Apply the D-09 access matrix on `data1` and prove it.
- **Previous state:** All six shared folders `root:users` 2700 (Phase 4).
- **Change performed:** Owner approval: "sí, apruebo el 5.3". In an interactive `ssh nas` session as
  owner-admin, with `D=/srv/dev-disk-by-uuid-aaaaaaaa-1111-4222-8333-444444444444`:
  `sudo chown alex "$D/private-alex"`; `sudo chown sam "$D/private-sam"`;
  `sudo chgrp family "$D/shared-family"`; `sudo chmod 2770 "$D/shared-family"`;
  `sudo setfacl -d -m u::rwx,g::rwx,o::--- "$D/shared-family"`; `sudo chown alex "$D/media"`;
  `sudo install -d -o alex -g users -m 2700 "$D/media/movies" "$D/media/tv" "$D/media/music"`.
  All non-recursive, on empty directories. No errors.
- **Affected devices/paths:** `private-alex`, `private-sam`, `shared-family`, `media`, and the new
  `media/{movies,tv,music}` on `data1` (HDD `HDDEX001`). `photos` and `backups` were not touched.
- **Approval:** Owner, in session, 2026-10-03.
- **Result / verification:** `stat` shows `private-alex` alex:users 2700, `private-sam` sam:users
  2700, `shared-family` root:family `drwxrws---`, `media` alex:users 2700, `photos`/`backups`
  root:users 2700. `sudo ls -la media` shows movies/music/tv alex:users `drwx--S---`. `getfacl`
  on shared-family shows `default:user::rwx`, `default:group::rwx`, `default:other::---`. Cross-user
  test (`for u in alex sam owner-admin; for d in …; sudo -u $u test -r -a -w -a -x`): alex RW on
  private-alex/shared-family/media only; sam RW on private-sam/shared-family only; owner-admin
  denied everywhere. This matches the matrix exactly. (A `stat "$D"/media/*` error was only a glob
  that did not expand for owner-admin, which cannot list `media`.) Phase 5 exit criteria:
  accounts/groups ✓, ownership & ACLs per folder ✓, cross-user access denied as intended ✓.
- **Rollback:** `chown root`, `chgrp users`, `chmod 2700`, `setfacl -b` on the same paths;
  `rmdir` the three empty media subfolders.
- **Docs updated:** CHANGELOG.md, docs/users-and-permissions.md, docs/roadmap.md, README.md,
  CLAUDE.md.

## 2026-10-03 — Phase 5.1–5.2: data accounts alex, sam and group family

- **Phase:** 5 (steps 5.1, 5.2)
- **Objective:** Per-person data accounts and a family group (D-09 decided).
- **Previous state:** Only `root`, `owner-admin` (1000) and the web `admin`.
- **Change performed:** OMV UI → Users → Users → Create: `alex`, `sam`, shell
  `/usr/sbin/nologin`, no extra groups, **Disallow account modification** checked. Passwords were
  generated in and stored only in the owner's KeePass. OMV UI → Users → Groups → Create: `family`
  with members alex and sam. Changes applied.
- **Affected devices/paths:** New accounts `alex` (UID 1001), `sam` (UID 1002), group `family`
  (GID 1000).
- **Approval:** Owner (D-09 approved), 2026-10-03.
- **Result / verification:** `id alex` → `uid=1001(alex) gid=100(users) groups=100(users),1000(family)`.
  `id sam` → `uid=1002(sam) gid=100(users) groups=100(users),1000(family)`.
  `getent group family` → `family:x:1000:sam,alex`. Both shells `/usr/sbin/nologin`.
- **Rollback:** Delete the users/group in the OMV UI.
- **Docs updated:** CHANGELOG.md, docs/users-and-permissions.md.

## 2026-10-03 — Phase 4: shared folders on data1; Phase 4 closed

- **Phase:** 4 (steps 4.1–4.3)
- **Objective:** Create the D-08 areas as locked-down OMV shared folders (D-05 = B: directly on
  `data1`; D-07 deferred to Phase 9).
- **Previous state:** `data1` mounted, empty except `lost+found`.
- **Change performed:** OMV UI → Storage → Shared Folders → Create, on `data1` (UUID
  `aaaaaaaa-1111-4222-8333-444444444444`), created 2026-10-01 to 2026-10-03: `private-alex`,
  `private-sam`, `shared-family`, `photos`, `media`, `backups`. Permissions preset: Administrator
  read/write, Users no access, Others no access. OMV used each folder name as its relative path,
  so the layout is flat, not the planned `private/alex` etc. The owner chose to keep it (option A).
  D-08 and storage.md §4.2 were amended. No data was written.
- **Affected devices/paths:** `/srv/dev-disk-by-uuid-aaaaaaaa-…/{private-alex,private-sam,shared-family,photos,media,backups}`
  on HDD `HDDEX001`; OMV shared-folder configuration.
- **Approval:** Owner, in session (D-05 B, D-07 deferred, D-08 approved 2026-10-01; flat variant
  2026-10-03).
- **Result / verification:** `sudo ls -la` on the `data1` root shows all six as
  `drwx--S--- root users`, `lost+found` as `drwx------ root root`, and the root itself as `drwxr-xr-x
  root root`. There are no world-readable or world-writable shared folders. Phase 4 exit criteria:
  shared folders per §4.2 (flat) ✓; no world-writable paths ✓.
- **Rollback:** Delete the (empty) shared folders in OMV.
- **Docs updated:** CHANGELOG.md, docs/decisions.md (D-08), docs/storage.md, docs/roadmap.md,
  docs/users-and-permissions.md, docs/architecture.md, README.md, CLAUDE.md.

## 2026-09-30 — Phase 3.4: data1 label + 1 % reserved; Phase 3 closed

- **Phase:** 3 (step 3.4, phase close)
- **Objective:** Fix the two deviations found after formatting: the missing label (D-03) and the
  reserved blocks (D-16).
- **Previous state:** `HDDEX001-part1`: `Filesystem volume name: <none>`, `Reserved block count: 0`.
- **Change performed:** Owner approval: "apruebo, etiqueta data1 y reserva de 1 %".
  (1) `sudo tune2fs -L data1 -m 1 /dev/disk/by-id/ata-ST2000NM0055-1V4104_HDDEX001-part1`. This set
  the label, but reserved stayed 0 and there was no "Setting reserved blocks" message and no error
  (cause not determined). (2) `sudo tune2fs -m 1 …-part1` printed `Setting reserved blocks
  percentage to 1% (4883783 blocks)` with `EXIT=0`. Superblock metadata only, done online. No
  data was touched.
- **Affected devices/paths:** `ata-ST2000NM0055-1V4104_HDDEX001-part1` (ext4 UUID
  `aaaaaaaa-1111-4222-8333-444444444444`).
- **Approval:** Owner, in session, 2026-09-30.
- **Result / verification:** `tune2fs -l` shows `Filesystem volume name: data1`, `Reserved block
  count: 4883783`. Mount by UUID unchanged. Phase 3 exit criteria: disk verified by serial ✓;
  formatted as `data1` ✓; mounted by OMV ✓; recorded in hardware.md ✓. D-16 → DECIDED (1 %).
- **Rollback:** `sudo tune2fs -L '' -m 0 …-part1`.
- **Docs updated:** CHANGELOG.md, docs/hardware.md, docs/storage.md, docs/decisions.md,
  docs/roadmap.md, README.md, CLAUDE.md.

## 2026-09-30 — Phase 3.2–3.3: data1 ext4 created and mounted

- **Phase:** 3 (steps 3.1–3.3)
- **Objective:** First data filesystem on the 2 TB disk (D-01 none, D-02 ext4, D-03 OMV UI/GPT/one
  partition/label `data1`).
- **Previous state (3.1, read-only, just before formatting):** `ata-ST2000NM0055-1V4104_HDDEX001` →
  `sda`, 2000398934016 bytes, no partition table (`fdisk -l`), `blkid -p` empty, not mounted. OS SSD
  `SSDEXAMPLE01` → `sdb` with `/`, `/boot/efi` and swap.
- **Change performed:** OMV UI → Storage → File Systems → Create → EXT4 on the ST2000NM0055 /
  `/dev/sda` / 1.82 TiB entry, then mounted through OMV and applied. **Destructive for `HDDEX001`
  only** (verified blank). The gate (exact action, device, risk) was presented in session. The owner
  carried out the format in the OMV UI without first sending the requested approval phrase, so the
  owner's own action counts as the approval.
- **Affected devices/paths:** HDD ST2000NM0055-1V4104 `HDDEX001` (`/dev/sda`): new GPT, `sda1` =
  `…_HDDEX001-part1`, ext4 UUID `aaaaaaaa-1111-4222-8333-444444444444`, mounted at
  `/srv/dev-disk-by-uuid-aaaaaaaa-1111-4222-8333-444444444444`. OMV-managed `/etc/fstab` line 18
  (by UUID, `defaults,nofail,user_xattr,usrquota,grpquota,acl`).
- **Approval:** Owner (see above), 2026-09-30.
- **Result / verification:** `lsblk`, `findmnt`, `tune2fs -l` and fstab all match. 488378385 × 4 KiB
  blocks, the whole disk. OS SSD unchanged (UUIDs `bbbbbbbb-…` `/`, `ABCD-1234` EFI,
  `cccccccc-…` swap). **Deviations:** (1) the filesystem has **no label** (`volume name: <none>`),
  although D-03 requires `data1`. (2) Reserved blocks are **0 %** (OMV's default), while D-16 proposes
  1–2 %. Both are pending the owner's decision (step 3.4).
- **Rollback:** None needed for data (the disk was blank). Removing the filesystem would itself be
  destructive.
- **Docs updated:** CHANGELOG.md, docs/hardware.md, docs/storage.md.

## 2026-09-30 — Phase 2 closed: self-test results

- **Phase:** 2 (step 2.3 result, 2.6, phase close)
- **Objective:** Verify both disks before the 2 TB disk is formatted (Phase 3), and close Phase 2.
- **Previous state:** Tests started at about 01:34 (-05). Steps 2.1, 2.2, 2.4, 2.5 done.
- **Change performed:** None on the server (read-only `smartctl -l selftest -A`). Docs updated.
- **Affected devices/paths:** HDD ST2000NM0055-1V4104 `HDDEX001`, SSD TOSHIBA KSG60ZMV256G
  `SSDEXAMPLE01` (read only).
- **Approval:** Owner, in session, 2026-09-30.
- **Result / verification:** HDD: `Extended offline — Completed without error` at 48 h (POH now
  56). Reallocated 0, Current_Pending 0, Offline_Uncorrectable 0, UDMA_CRC 0, Reported_Uncorrect 0,
  End-to-End 0, Total_LBAs_Written 0, temperature 30 °C. SSD: `Short offline — Completed without
  error` at 7437 h. Phase 2 exit criteria: SMART enabled on both disks ✓, scheduled short/long
  tests ✓, temperature thresholds ✓, long test on 2 TB passed ✓, alert test email received ✓.
  F-11 resolved. D-04 unchanged (no errors), so the disk is cleared for Phase 3.
- **Rollback:** n/a.
- **Docs updated:** CHANGELOG.md, docs/hardware.md, docs/roadmap.md, README.md, CLAUDE.md.

## 2026-09-30 — Phase 2.4–2.5: scheduled self-tests and SMART alert test

- **Phase:** 2 (steps 2.4, 2.5)
- **Objective:** Recurring self-tests, and proof that SMART alerts reach the owner by email.
- **Previous state:** No scheduled tests. SMART critical temperature 60 °C.
- **Change performed:** 2.4: OMV UI → Storage → S.M.A.R.T. → Scheduled tests, four entries. For
  `HDDEX001` and `SSDEXAMPLE01`: short weekly (Sunday 02:00); long monthly on the 1st (HDD 03:00,
  SSD 04:00). 2.5: critical temperature temporarily set to 20 °C (both disks were at about
  27–31 °C) to trigger an alert, then to be restored to 60 °C.
- **Affected devices/paths:** OMV SMART settings / `smartd` configuration (both disks).
- **Approval:** Owner, Phase 2 plan approved in session, 2026-09-30.
- **Result / verification:** 2.4 done per the owner. 2.5: the SMART critical-temperature alert email
  was received, so the path smartd → OMV notification → Gmail SMTP → owner works. The threshold
  was first put back at 50 °C, then set to **60 °C** as planned. 50 °C risked false alerts from
  the OS SSD, which has a lifetime maximum of 76 °C. Note: in OMV 8 the email-alert field is labelled
  **Maximum**, not "Critical".
- **Rollback:** Delete scheduled tests. Critical temperature back to 60 °C.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md.

## 2026-09-30 — Phase 2.1–2.3: SMART monitoring enabled, first self-tests started

- **Phase:** 2 (steps 2.1, 2.2, 2.3 started)
- **Objective:** Continuous disk health monitoring with email alerts, and a verified long test on
  the 2 TB disk before Phase 3 (D-04).
- **Previous state:** SMART monitoring not configured. The HDD had never run a self-test (F-11). The
  SSD's last short tests were "Aborted by host" (F-10).
- **Change performed:** 2.1: OMV UI → Storage → S.M.A.R.T. → Settings: enabled, check interval
  1800 s, power mode Standby, temperature difference 0, informal 50 °C, Maximum 60 °C. 2.2:
  S.M.A.R.T. → Devices: monitoring activated on both disks (matched by serial). 2.3: started at about
  01:34 (-05), `sudo smartctl -t long /dev/disk/by-id/ata-ST2000NM0055-1V4104_HDDEX001` (206 min,
  expected to finish around 04:59) and `sudo smartctl -t short
  /dev/disk/by-id/ata-TOSHIBA_KSG60ZMV256G_M.2_2280_256GB_SSDEXAMPLE01`. Both drives replied
  "Testing has begun". Self-tests are non-destructive (read-only).
- **Affected devices/paths:** HDD ST2000NM0055-1V4104 `HDDEX001`, SSD TOSHIBA KSG60ZMV256G
  `SSDEXAMPLE01` (by-id paths above); OMV SMART settings / `smartd` configuration.
- **Approval:** Owner approved the Phase 2 plan in session, 2026-09-30.
- **Result / verification:** 2.1/2.2 done per the owner. Self-test results are pending (see the Phase 2
  close entry).
- **Rollback:** Uncheck SMART Enabled / device monitoring. A running test can be aborted with
  `smartctl -X`.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md.

## 2026-09-30 — Phase 1 closed

- **Phase:** 1
- **Objective:** Close Phase 1 once every exit criterion is met.
- **Previous state:** Steps 1.1–1.12 done individually (entries below).
- **Change performed:** Documentation only. Roadmap, README and CLAUDE.md now show Phase 1 complete,
  awaiting Phase 2 approval.
- **Affected devices/paths:** None.
- **Approval:** Owner, in session, 2026-09-30 ("cierra la fase 1").
- **Result / verification:** Exit criteria: OMV up to date (1.2) ✓; admin password changed
  (1.4) ✓; named admin account with SSH key (1.6) ✓; SSH root/password login off (1.7) ✓; HTTPS
  UI (1.8) ✓; NTP (1.3) ✓; email notifications working (1.10) ✓; config exported off-repo
  (1.12) ✓.
- **Rollback:** n/a.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md, README.md, CLAUDE.md.

## 2026-09-30 — Phase 1.12: OMV configuration exported off-repo

- **Phase:** 1 (step 1.12)
- **Objective:** Keep a copy of the OMV configuration off the NAS for rebuilds (the OS SSD shows
  wear, F-10).
- **Previous state:** No config export existed.
- **Change performed:** `ssh -t nas "sudo install -m 600 -o owner-admin -g users
  /etc/openmediavault/config.xml /tmp/omv-config.xml && sudo sha256sum /etc/openmediavault/config.xml"`,
  then `scp nas:/tmp/omv-config.xml` to the PC's Downloads folder, then `ssh nas "rm
  /tmp/omv-config.xml"` (removed only the temporary copy). The file was attached to an entry
  "OMV config 2026-09-30" in the owner's KeePass database, and the local copy was deleted by the
  owner. It was **never** placed in the repo (it contains password hashes, the SMTP app password
  and the HTTPS private key).
- **Affected devices/paths:** `/tmp/omv-config.xml` on the NAS (created and removed). The
  original `/etc/openmediavault/config.xml` was only read.
- **Approval:** Owner, in session, 2026-09-30.
- **Result / verification:** The SHA-256 of the local copy matched the original on the NAS (owner
  report). The attachment is stored in KeePass.
- **Rollback:** n/a. Repeat after significant OMV changes; to be automated in Phase 13.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md.

## 2026-09-30 — Phase 1.11: internet exposure check (no change)

- **Phase:** 1 (step 1.11)
- **Objective:** Confirm that nothing on the NAS is reachable from the internet (F-01, F-20),
  without router admin access.
- **Previous state:** The router is ISP-managed. Port forwards and UPnP state were unknown.
- **Change performed:** None. **No changes were made to the server or router.** Read-only checks were
  run from the operator PC.
- **Affected devices/paths:** None.
- **Approval:** Owner, in session, 2026-09-30.
- **Result / verification:** `tracert -d 1.1.1.1` shows hop 1 `192.168.10.1` (home router) and hop 2
  `100.64.12.1`, hop 3 `100.64.34.1`. Those are in `100.64.0.0/10`, the carrier-grade NAT range.
  The home router therefore has **no public IPv4 of its own**, and unsolicited inbound connections
  cannot reach the LAN, whatever the router's port forwards or UPnP state. The PC has only ULA IPv6
  (`fdxx:…`) and no global IPv6, so there is no IPv6 inbound path either. An owner test with
  `ssh <public IP>` timed out. The IP used looked like a third-party range, so that test is not
  conclusive; the tracert evidence is the basis. **Accepted:** UPnP cannot be disabled without router
  access, which has no inbound effect under CGNAT. **Re-check trigger:** if the ISP ever assigns a
  public IPv4 or global IPv6 (or the owner asks for port opening), repeat this check. Remote access
  is planned via Tailscale (Phase 11), which works behind CGNAT.
- **Rollback:** n/a.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md, docs/network.md.

## 2026-09-30 — Phase 1.10: email notifications

- **Phase:** 1 (step 1.10)
- **Objective:** Let the NAS alert the owner (disk, services, and later backups).
- **Previous state:** Notifications not configured.
- **Change performed:** OMV UI → System → Notification → Settings: enabled, SMTP `smtp.gmail.com:587`,
  STARTTLS, authentication with a Gmail app password (the owner was advised to use a dedicated
  NAS-only sender account). The owner's personal address is the primary recipient. Default events
  are enabled in the Notifications tab. The app password was entered by the owner and is stored
  only in the password manager and the OMV config. It is not in this repo or the session.
- **Affected devices/paths:** OMV notification settings (credentials in `config.xml`, which must
  never go to Git).
- **Approval:** Owner, in session, 2026-09-30.
- **Result / verification:** "Send a test email" was received by the owner.
- **Rollback:** Uncheck Enabled, or revoke the app password in the Google account.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md.

## 2026-09-30 — Phase 1.9: unused services review (no change)

- **Phase:** 1 (step 1.9)
- **Objective:** Minimise listening services.
- **Previous state:** Phase 0 `ss -tulpn` found no FTP, NFS share, Rsync server or SMB listeners.
  Beyond SSH and nginx, the listeners are avahi (5353/udp), systemd-resolved LLMNR (5355) and
  rpcbind (111).
- **Change performed:** None. **No changes were made to the server.** avahi is kept because it
  provides `nas.local`. LLMNR is kept (Debian default, low risk). rpcbind is an **accepted risk
  until Phase 11**: it is LAN-only, disabling it would mean hand-editing a system service that OMV
  manages, and it will be filtered by the host firewall in Phase 11.
- **Affected devices/paths:** None.
- **Approval:** Owner, in session, 2026-09-30.
- **Result / verification:** Based on the Phase 0 inventory (unchanged since).
- **Rollback:** n/a.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md, docs/network.md.

## 2026-09-30 — Phase 1.8: HTTPS for the OMV web UI

- **Phase:** 1 (step 1.8)
- **Objective:** Encrypt web UI traffic on the LAN, so admin credentials are no longer sent in clear
  over HTTP (Phase 0: nginx on port 80 only, nothing on 443).
- **Previous state:** OMV web UI on HTTP port 80 only.
- **Change performed:** OMV UI → System → Certificates → SSL → Create: a self-signed certificate
  with CN `nas.internal`, 5-year validity. Then System → Workbench → SSL/TLS enabled with that
  certificate on port 443, and applied. After HTTPS was confirmed working, **Force SSL/TLS** was
  enabled (HTTP now redirects to HTTPS).
- **Affected devices/paths:** OMV Workbench (nginx) configuration; new certificate in the OMV
  certificate store (the private key stays on the NAS).
- **Approval:** Owner, in session, 2026-09-30.
- **Result / verification:** The owner reports `https://192.168.10.250` works (expected
  self-signed browser warning). Additionally, `nas.local` resolves to `192.168.10.250` from the
  operator PC through mDNS (avahi), which gives a working name while `nas.internal` does not (F-09).
- **Rollback:** Disable SSL/TLS in System → Workbench, or use `omv-firstaid` from the console.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md, docs/network.md.

## 2026-09-30 — Phase 1.1: static IP 192.168.10.250 (D-18)

- **Phase:** 1 (step 1.1)
- **Objective:** Give the NAS a stable address before the HTTPS certificate (1.8) embeds it (F-08).
- **Previous state:** DHCP `192.168.10.108/24` on `enp0s31f6`, gateway/DNS `192.168.10.1`. There was
  no known reservation and no router admin access (F-20).
- **Change performed:** In the OMV UI (Network → Interfaces → `enp0s31f6`), IPv4 was set to Static:
  `192.168.10.250`, netmask `255.255.255.0`, gateway `192.168.10.1`, DNS `192.168.10.1`. IPv6 was
  unchanged, and the Wi-Fi interface `wlp0s20f3` was not touched. D-18 changed from a DHCP
  reservation to a static IP in OMV, because the owner prefers not to involve the ISP. A ping/arp
  free-address check of `.250` from the PC was proposed beforehand.
- **Affected devices/paths:** NAS interface `enp0s31f6` (Intel I219-V); OMV network config.
- **Approval:** Owner, in session, 2026-09-29/30, after the risk/rollback explanation.
- **Result / verification:** A key-based SSH session to `owner-admin@192.168.10.250` works.
  `ip -br addr` shows `enp0s31f6 UP 192.168.10.250/24`, the route shows `default via 192.168.10.1 proto
  static`, and `resolvectl dns` shows `192.168.10.1`. Residual risk: an IP conflict if the router's
  DHCP pool includes `.250`.
- **Rollback:** Physical console → `omv-firstaid` → Configure network interface → DHCP.
- **Docs updated:** CHANGELOG.md, docs/network.md (also SSH policy table updated for 1.7),
  docs/decisions.md (D-18), docs/roadmap.md.

## 2026-09-29 — Phase 1.7 follow-up: X11 forwarding off (F-04)

- **Phase:** 1 (step 1.7)
- **Objective:** Disable unused X11 forwarding.
- **Previous state:** `x11forwarding yes`. The OMV template writes `X11Forwarding yes` at
  `/etc/ssh/sshd_config` line 16. An Extra options line `X11Forwarding no` (line 33) was ignored
  because sshd uses the first value it reads. Line 36 is `Include /etc/ssh/sshd_config.d/*.conf`,
  and that directory is empty.
- **Change performed:** OMV UI → Services → SSH → Extra options set to
  `Match all` / `    X11Forwarding no`, saved and applied. Values inside a `Match` block override
  the global value.
- **Affected devices/paths:** `/etc/ssh/sshd_config` (generated by OMV).
- **Approval:** Owner, in session, 2026-09-29.
- **Result / verification:** A new key-based session succeeded, so sshd restarted cleanly. The owner
  reports `sshd -T -C user=owner-admin,host=laptop,addr=192.168.10.123` shows `x11forwarding no`.
  Plain `sshd -T` ignores Match blocks, so always use `-C` to check this setting.
- **Rollback:** Clear Extra options in Services → SSH and apply.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md.

## 2026-09-29 — Phase 1.7: SSH hardening (root login and password auth off)

- **Phase:** 1 (step 1.7)
- **Objective:** Key-only SSH, with no direct root login (F-01, threats T5/T6/T9).
- **Previous state:** `sshd -T` showed `permitrootlogin yes`, `passwordauthentication yes`,
  `pubkeyauthentication yes`, `x11forwarding yes` (Phase 0).
- **Change performed:** In the OMV UI (Services → SSH), the owner unchecked **Permit root login** and
  **Password authentication**, kept **Public key authentication**, and applied the change. The
  owner's approval was implied by applying the change after the explanation. **TCP forwarding** and
  **Compression** show unchecked. The OMV SSH page has no X11 checkbox.
- **Affected devices/paths:** sshd configuration generated by OMV. Port 22 unchanged.
- **Approval:** Owner, in session, 2026-09-29, after the risk/rollback explanation.
- **Result / verification:** A new session using the `owner-admin` key ran
  `sudo sshd -T`, which printed `permitrootlogin no`, `passwordauthentication no`,
  `pubkeyauthentication yes`. **`x11forwarding yes` is still set** (F-04 remains open). The Debian
  default cannot be changed with an OMV checkbox. New finding: login prints `Could not chdir to home
  directory /home/owner-admin` (no home directory exists because OMV has no user-home shared folder
  yet). This is harmless because OMV keeps the authorized keys outside the home directory. It is
  deferred to Phase 4/5.
- **Rollback:** Re-check the options in Services → SSH, or run `omv-firstaid` from the console.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md.

## 2026-09-29 — Phase 1.6: named admin account `owner-admin` with SSH key

- **Phase:** 1 (step 1.6)
- **Objective:** Replace root-based administration with a named sudo account that logs in with a
  key. This is the precondition for step 1.7 (F-01, F-03).
- **Previous state:** Only `root` and the web `admin` (nologin). The `_ssh` and `sudo` groups
  had no members.
- **Change performed:** OMV UI → Users → Users → Create: `owner-admin`, shell `/usr/bin/bash`,
  groups `_ssh`, `sudo`, `users`. The sudo password came from the owner's password manager and was
  not shared. The public key `id_ed25519_nas.pub` (ed25519, fingerprint
  `SHA256:EXAMPLEkeyOneAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA`) was added in the user's SSH public keys,
  and the pending changes were applied. The key was generated on the owner's PC with a passphrase,
  and the private key never left the PC.
- **Affected devices/paths:** New Linux account `owner-admin` (UID 1000); OMV user database.
- **Approval:** Owner, in session, 2026-09-29.
- **Result / verification:** A second PowerShell session ran `ssh -i ~/.ssh/id_ed25519_nas -o IdentitiesOnly=yes
  -o PasswordAuthentication=no owner-admin@192.168.10.108` and logged in with the key. `id` returned
  `uid=1000(owner-admin) gid=100(users) groups=100(users),27(sudo),102(_ssh)`, and
  `sudo -v && echo SUDO_OK` printed `SUDO_OK`. Root SSH login is unchanged (still enabled until 1.7).
- **Rollback:** OMV UI → Users → Users → delete `owner-admin`.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md, docs/users-and-permissions.md.

## 2026-09-29 — Phase 1.4 + 1.5: web admin password and session timeout

- **Phase:** 1 (steps 1.4, 1.5)
- **Objective:** Replace the default OMV web `admin` password and limit idle web sessions (T9).
- **Previous state:** The web `admin` password had not been changed since installation, and no
  idle auto-logout was configured.
- **Change performed:** The owner changed the web `admin` password in the OMV UI (user menu →
  Change Password). The new password was generated by and stored in the owner's password manager,
  and was never shared in session or stored in the repo. The owner also set the idle auto-logout
  in System → Workbench.
- **Affected devices/paths:** OMV web UI account `admin` (UID 996); OMV Workbench setting.
- **Approval:** Owner, in session, 2026-09-29.
- **Result / verification:** The owner reports both steps are done (log out/in with the new
  password).
- **Rollback:** Password: `omv-firstaid` from the physical console. Timeout: revert in System →
  Workbench.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md.

## 2026-09-29 — Phase 1.3: time zone + NTP (already in place)

- **Phase:** 1 (step 1.3)
- **Objective:** Correct time zone and NTP synchronisation (needed for logs, certificates, scheduled
  jobs).
- **Previous state:** The Phase 0 inventory (`timedatectl`) showed time zone `America/Chicago` and
  the clock NTP-synchronised by chrony (F-15).
- **Change performed:** None. The step was already satisfied, so the owner chose not to re-verify.
  **No changes were made to the server.**
- **Affected devices/paths:** None.
- **Approval:** Owner, in session, 2026-09-29.
- **Result / verification:** Based on the Phase 0 inventory evidence (2026-09-29).
- **Rollback:** n/a.
- **Docs updated:** CHANGELOG.md, docs/roadmap.md.

## 2026-09-29 — Phase 1.2: update check (none pending)

- **Phase:** 1 (step 1.2)
- **Objective:** Bring OMV/Debian up to date before hardening.
- **Previous state:** OMV 8.5.9-1 on Debian 13.7, kernel 7.1.13+deb13-amd64. Phase 0 found no
  pending updates, but the apt cache was not refreshed (F-13).
- **Change performed:** The owner checked for updates in the OMV UI (System → Update Management →
  Updates). None were listed, so nothing was installed and there was no reboot. **No changes were made
  to the server.** Step 1.1 (DHCP reservation, D-18) is still pending with the ISP. Step 1.2 was done
  first because it does not depend on the IP.
- **Affected devices/paths:** None.
- **Approval:** Owner, in session, 2026-09-29.
- **Result / verification:** The OMV UI shows no pending updates (owner report). Versions are
  unchanged from docs/hardware.md.
- **Rollback:** n/a (nothing changed).
- **Docs updated:** CHANGELOG.md, docs/roadmap.md.

## 2026-09-29 — Phase 0: read-only discovery

- **Phase:** 0
- **Objective:** Capture a verified inventory of the real server, document it, and make the
  pre-format decisions, without changing the server.
- **Previous state:** OMV installed; hardware.md/network.md full of `TBD`; no inventory run;
  D-01..D-04 PROPOSED, D-06 OPEN.
- **Change performed:** Read-only inventory. **No changes were made to the server.** The owner ran
  `scripts/discovery-readonly.sh` twice from Git Bash on the PC (R-01 case B-root,
  `ssh root@192.168.10.108 'bash -s' < scripts/discovery-readonly.sh`). Output was saved only in
  the git-ignored `discovery-raw/` on the PC. Before the first run the owner, still logged in to the
  NAS, ran `mkdir -p discovery-raw` and created an empty `/root/discovery-raw`. The owner removed it
  with `rmdir /root/discovery-raw` (empty folders only), so the net server change is none. Repo-side:
  `.gitattributes` pins `*.sh` to LF, and the script gained read-only commands (`timedatectl`,
  ATA port listing, cache-free `blkid` + `blkid -p`, `apt-cache policy`, extra `sshd -T` keys).
  The router is ISP-managed and could not be inspected (no admin access).
- **Affected devices/paths:** None on the NAS. Disks inventoried: OS SSD TOSHIBA KSG60ZMV256G,
  serial SSDEXAMPLE01; data HDD ST2000NM0055-1V4104, serial HDDEX001 (blank, untouched).
- **Approval:** Owner ran every server command; decisions D-01, D-02, D-03, D-04, D-06 and D-10
  approved by the owner in session, 2026-09-29.
- **Result / verification:** Both runs complete (all sections, `Done` marker). The stable-section
  diff (fstab, findmnt, blkid, dpkg-query, SSH config, users/groups, APT, firewall) is identical
  between runs, and the HDD reports 0 sectors written. Every documented value was traced to the
  raw output. `grep -c TBD` is 0 for hardware.md and network.md. The identifier scan was empty
  before each commit. Findings F-01..F-20 are recorded for Phase 1+, and none were fixed.
- **Rollback:** n/a (nothing changed on the server).
- **Docs updated:** docs/hardware.md, docs/network.md, docs/phase-0-discovery.md,
  docs/decisions.md, docs/roadmap.md, README.md, scripts/README.md,
  scripts/discovery-readonly.sh, .gitattributes.

## 2026-09-29 — Phase 0: documentation baseline

- **Phase:** 0
- **Objective:** Create the documentation structure and initial architecture before touching the server.
- **Previous state:** Empty repository.
- **Change performed:** Added README, CLAUDE.md, docs (architecture, storage, security, hardware,
  network, users-and-permissions, backups, disaster-recovery, roadmap, decisions, phase-0-discovery),
  read-only discovery script, `.gitignore` for secrets.
- **Affected devices/paths:** None on the NAS. **No changes were made to the server.**
- **Result / verification:** n/a (documentation only).
- **Rollback:** n/a.
