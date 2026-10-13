# Contract: `scripts/discovery-readonly.sh`

## Guarantees

1. It writes **nothing** on the server: no files, no config, no package or index changes, no
   SMART tests, no mounts. All output goes to stdout/stderr.
2. It runs as root (directly or through sudo). A command whose tool is missing prints a notice
   instead of failing the run.
3. The output contains serials, MAC addresses and IPs. It MUST be stored only in
   `discovery-raw/` on the operator's PC.
4. The file has LF line endings, pinned by `.gitattributes`.

## Command allowlist

Only commands in this list (with read-only flags) may appear in the script. Adding a command
means adding it here first, with a reason.

| Command | Allowed form | Notes |
|---|---|---|
| `date`, `uptime`, `hostnamectl`, `uname -a`, `timedatectl` | no arguments that set anything | status only |
| `cat` | `/etc/os-release`, `/etc/fstab`, `/etc/resolv.conf` | reads |
| `dpkg-query -W` | any pattern | reads the package DB |
| `apt list --upgradable`, `apt-cache policy <pkgs>` | never `apt update/install` | reads the existing cache |
| `ls` | `-l` on `/dev/dri`, `/dev/disk/by-id/`, `/etc/apt/sources.list.d/`, `/sys/class/ata_port` | listings |
| `lscpu`, `free -h`, `lspci -nnk` | as is | reads |
| `dmidecode -t <type>` | read only | |
| `lsblk -o …`, `findmnt --real`, `df -hT`, `fdisk -l` | `fdisk` **only** with `-l` | list mode |
| `blkid -c /dev/null`, `blkid -p -o full <disk>` | probe only | `-c /dev/null` skips the blkid cache file under `/run`, and `-p` doesn't use the cache. The existing plain `blkid` call is switched to `-c /dev/null`. |
| `smartctl --scan`, `smartctl -x <dev>` | **never** `-t`, `-s`, `-o`, `-S` | `-x` may spin up a disk; that's acceptable |
| `ip -br link/addr`, `ip route`, `ss -tulpn` | show only | |
| `systemctl --failed`, `systemctl list-units` | never start/stop/enable | |
| `docker version`, `docker ps -a`, `tailscale status` | only if installed | |
| `sshd -T` piped to `grep` | print config | |
| `getent passwd`, `getent group` | no shadow data | |
| `nft list ruleset`, `iptables -S` | list only | |
| `journalctl -p err -b -n 100` | reads | |

**Forbidden in this script:** `wipefs` (any flags), `mkfs*`, `parted`, `sgdisk`, `fdisk`
without `-l`, `dd`, `hdparm`, `smartctl -t/-s/-o/-S`, `mount`, `umount`, `apt update`,
`apt install`, `apt upgrade`, `systemctl start/stop/restart/enable/disable`,
`chmod`, `chown`, `tee` or `>` to a server path, `omv-*` commands that apply config.

## Output sections (the order is stable, and R-04 diffs depend on it)

`Identity / OS` · `CPU / memory / board` · `PCI devices` · `Block devices` · `SMART` ·
`OMV plugin availability` *(new)* · `Network` · `Services` · `SSH effective config` ·
`Users and groups` · `APT sources / pending updates` · `Firewall state` · `Recent errors` ·
`Done`

**Stable sections for the R-04 no-change diff**: `/etc/fstab`, `findmnt`, `blkid`,
`dpkg-query`, `SSH effective config`, `Users and groups`, `APT sources`, `Firewall state`.

The run is complete if the last line block is `==================== Done ====================`.
If it's missing, the run was interrupted and must be repeated.
