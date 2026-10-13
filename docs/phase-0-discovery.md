# Phase 0 — Discovery

Status: **Complete (awaiting Phase 1 approval)**, 2026-09-29. Inventory captured and documented,
router state recorded (no admin access, deferred to Phase 1), pre-format decisions made.
Last updated: 2026-09-29

## 1. What Phase 0 covers

| Step | Status |
|---|---|
| Repository and documentation structure | Done (2026-09-29) |
| Architecture, storage, security, hardware drafts | Done (2026-09-29) |
| Implementation roadmap | Done (2026-09-29) — [roadmap.md](roadmap.md) |
| List of decisions required before formatting | Done (2026-09-29) — [decisions.md](decisions.md); D-01, D-02, D-03, D-04, D-06, D-10 DECIDED |
| **Read-only inventory of the real server** | Done (2026-09-29, two runs, no change detected) |
| Router check (port forwards, UPnP, DHCP reservation) | Done as far as possible (2026-09-29): ISP-managed router, no admin access; open items deferred to Phase 1 (F-20) |
| Fill `TBD` values in hardware.md | Done (2026-09-29) |

Phase 0 ends when the inventory is done and the pre-format decisions are made.

## 2. How to run the inventory

Everything in [scripts/discovery-readonly.sh](../scripts/discovery-readonly.sh) is
**read-only** (listings, `smartctl -x` data output, `sshd -T`, `apt list` and
`apt-cache policy` without refreshing indexes). It does not start SMART tests, write
files, or change settings. The full step-by-step guide, including the pre-run checks
and the second run that proves nothing changed, is
[specs/001-phase0-discovery/quickstart.md](../specs/001-phase0-discovery/quickstart.md).

Run the commands below in **Git Bash** on the PC, from the repo root, **not
PowerShell**. Output is saved on the PC only; nothing is written on the NAS.

Options (owner chooses the one that matches how you log in):

```bash
D=discovery-raw/discovery-$(date +%F).txt

# B-root
ssh root@nas.internal 'bash -s' < scripts/discovery-readonly.sh > "$D" 2>&1

# B-sudo-nopw
ssh <user>@nas.internal 'sudo bash -s' < scripts/discovery-readonly.sh > "$D" 2>&1

# B-sudo-pw (sudo will ask for your password; type it when prompted)
ssh -t <user>@nas.internal "sudo bash -c \"\$(echo $(base64 -w0 scripts/discovery-readonly.sh) | base64 -d)\"" | tee "$D"
```

- **A. Local console** on the NAS (keyboard + monitor): run
  `sudo bash discovery-readonly.sh | less` and write down the answers. Don't save
  output on the NAS or on a USB stick.
- **C. Claude runs it over SSH** — only if you explicitly authorize a specific
  connection method (host, user, key). Not done by default.

Then share the output (or the relevant parts). Raw output stays in
`discovery-raw/` (git-ignored — contains serials, MACs, IPs).

## 3. What we are looking for

| Question | Why it matters |
|---|---|
| Exact OMV 8 and Debian version, installed OMV plugins, omv-extras present? | Plugin availability (mergerfs, snapraid, compose, sharerootfs) |
| Does `/dev/sda` (serial …) contain partitions/filesystems/data? | Decision D-06 before any format |
| SMART of both disks: power-on hours, reallocated/pending/uncorrectable sectors, CRC errors, SSD wear | Is the 2 TB disk fit for Tier 1 data? Is the SSD healthy enough to host app state? |
| Disk interface: direct SATA vs USB bridge | SMART reliability, spin-down behaviour |
| OS SSD partition layout and free space | App data / DB placement (D-11) |
| CPU model and `/dev/dri` | Jellyfin/Immich hardware transcoding |
| RAM size (ECC?) | Container budget, Immich ML feasibility |
| IP config (DHCP vs static), interfaces | Phase 1/11 without lockout |
| Listening services (`ss -tulpn`) | Current attack surface |
| SSH effective config (root login? password auth?) | Phase 1 hardening baseline |
| Existing users/groups | UID/GID plan (D-09) |
| Firewall rules present? | Avoid conflicting with existing rules |
| Pending updates | Phase 1 step 1 |

## 4. Router checks (owner, via router UI — read only)

Checked 2026-09-29. The router (gateway `192.168.10.1`) is managed by the ISP and the owner has
**no admin access** to its web UI. The owner can ask the ISP about its configuration. By the
owner's choice, the unanswered items are deferred to Phase 1 (steps 1.1 and 1.11) and Phase 0
continues.

- [x] Router make/model — **unknown**: ISP-managed, no admin access (can be read from the device label)
- [x] Any existing port forwards? — **unknown**: cannot be checked without admin access; ask the ISP (finding F-20)
- [x] UPnP / NAT-PMP enabled? — **unknown**: cannot be checked without admin access; ask the ISP (finding F-20)
- [x] NAS has a DHCP reservation? Current IP? — Current IP `192.168.10.108` (DHCP, from the inventory); reservation **unknown** — ask the ISP (decision D-18)
- [x] Guest network / separate IoT network available? — **unknown**: no admin access; ask the ISP

## 5. Results

### Run metadata

| Item | Value |
|---|---|
| Date | 2026-09-29, run 1 at 20:40 -05, run 2 about 20:41 -05 |
| Run method | R-01 case **B-root**: `ssh root@192.168.10.108 'bash -s' < scripts/discovery-readonly.sh`, from Git Bash on the operator PC. The IP was used because `nas.internal` does not resolve from the PC |
| Output | `discovery-raw/discovery-2026-09-29.txt` and `discovery-raw/discovery-2026-09-29-2.txt` (git-ignored). Both have every contract section and end with the `Done` marker |
| No-change proof (R-04) | Stable sections **identical** between run 1 and run 2: `/etc/fstab`, `findmnt`, `blkid` (including `-p` probes), `dpkg-query`, SSH effective config, users and groups, APT sources and pending updates, firewall. Also identical: `lsblk`, `fdisk -l`, `/dev/disk/by-id`, `ip -br addr`, `ss -tulpn`. The 2 TB disk reports 0 sectors written in both runs |
| Incident | Before run 1 the owner, still logged in to the NAS, ran `mkdir -p discovery-raw` and created an empty `/root/discovery-raw`. The owner removed it with `rmdir` (only removes empty folders). Net server change: none |
| Gaps | NIC negotiated link speed was not captured. Docker and Tailscale are not installed. Physical items (PSU, case, free bays, BIOS password) need the owner's physical check |

### Answers to §3

| Question | Answer |
|---|---|
| OMV / Debian version, plugins, omv-extras | OMV 8.5.9-1 on Debian 13.7 (trixie), kernel 7.1.13+deb13-amd64 (backports). **No OMV plugins** installed. **omv-extras not present**. mergerfs, snapraid, compose and luksencryption have no install candidate in the configured repos; sharerootfs 8.0.1-1 is available |
| Does the 2 TB disk contain partitions/filesystems/data? | **No.** ST2000NM0055-1V4104, serial HDDEX001: `blkid -p` prints nothing, no partition table in `fdisk -l`, nothing in `lsblk`, not mounted, not in fstab |
| SMART of both disks | HDD HDDEX001: PASSED, 40 POH, 0 reallocated / pending / offline-uncorrectable / CRC, never self-tested. SSD SSDEXAMPLE01: PASSED, 7433 POH, 0 reallocated / CRC, **30 % endurance used**, 55260 min in over-temperature (lifetime max 76 °C). Details: [hardware.md](hardware.md) §2 |
| Disk interface | Both disks are direct SATA on the Intel H610 AHCI controller (6.0 Gb/s). No USB bridge |
| OS SSD layout and free space | GPT: 976M EFI, 225.2G ext4 `/` (207G free), 12.3G swap |
| CPU and `/dev/dri` | Intel Core i3-12100 with UHD Graphics 730 (`i915`). `/dev/dri/card0` and `renderD128` are present |
| RAM (ECC?) | 16 GB (2 × 8 GB DDR4-2667), **no ECC**, both slots used, max 64 GB |
| IP config, interfaces | **DHCP**, 192.168.10.108/24 on `enp0s31f6` (Intel I219-V). Gateway and DNS 192.168.10.1. Wi-Fi interface is down |
| Listening services | 22/tcp sshd, 80/tcp nginx (HTTP only, no 443), 111 rpcbind, 5355 LLMNR, 5353 mDNS, all on every interface. Only local-only services otherwise. Table in [network.md](network.md) |
| SSH effective config | Root login **yes**, password auth **yes**, pubkey yes, X11 forwarding yes, empty passwords no, AllowGroups `root` `_ssh` |
| Existing users/groups | Only `root` and the web UI `admin` account (UID 996, no login shell). `_ssh` and `sudo` groups have no members. `users` = GID 100 |
| Firewall rules present? | **No.** nftables ruleset empty, iptables policy ACCEPT with 0 rules |
| Pending updates | None listed in the current apt cache (the script does not refresh it). Recheck in Phase 1 step 1.2 |

### Findings

Findings are recorded here and **not fixed in Phase 0**.

| ID | Observation | Severity | Addressed in |
|---|---|---|---|
| F-01 | SSH allows root login with a password on every interface (`permitrootlogin yes`, `passwordauthentication yes`) | Medium (High if a router forward to port 22 exists) | Phase 1 (1.6, 1.7) |
| F-02 | The web UI is served only over HTTP (nginx on 80, nothing on 443). The admin password crosses the LAN unencrypted | Medium | Phase 1 (1.8) |
| F-03 | No named admin account: only `root` and the web `admin` (nologin). `_ssh` and `sudo` have no members | Low | Phase 1 (1.6) |
| F-04 | `x11forwarding yes` in sshd | Low | Phase 1 (1.7) |
| F-05 | `rpcbind` listens on 111 tcp/udp on all interfaces, but no NFS share is configured | Low | Phase 1 (1.9) |
| F-06 | LLMNR (5355) and mDNS (5353) listen on all interfaces | Info | Phase 1 (1.9) |
| F-07 | No host firewall (nftables empty, iptables 0 rules) | Info | Phase 11 |
| F-08 | The NAS gets its IP by DHCP (192.168.10.108). Whether the router has a reservation is not yet known | Medium | Phase 1 (1.1), decision D-18 |
| F-09 | `nas.internal` does not resolve from the operator PC (PC DNS suffix `lan`, NAS search domain `internal`) | Low | Phase 1 (1.1), decision D-18 |
| F-10 | The OS SSD is used: 7433 POH, 30 % endurance used, 1437 power cycles, 55260 min in over-temperature (lifetime max 76 °C, spec max 40 °C), last self-tests aborted. SMART PASSED, 0 reallocated | Medium | Phase 2 (SMART monitoring), decision D-11, Phase 1 (1.12 config export) |
| F-11 | The 2 TB HDD has never run a SMART self-test (40 POH, all error counters 0) | Low | Phase 2, decision D-04 |
| F-12 | omv-extras not installed. mergerfs, snapraid, compose and luksencryption plugins are not installable from the configured repos | Info | Phase 4 / Phase 7, decision D-01 |
| F-13 | No pending updates in the current apt cache (cache not refreshed by the script) | Info | Phase 1 (1.2) |
| F-14 | No failed systemd units | Info | — |
| F-15 | Journal errors this boot are only collectd → rrdcached "illegal attempt to update" (last RRD update about 3.5 h in the future, so the clock moved backwards). The clock is now NTP-synchronised (chrony, America/Chicago) | Low | Phase 1 (1.3), Phase 12 |
| F-16 | Wi-Fi adapter present and down, but `wpa_supplicant` is running | Info | Phase 1 (1.9) |
| F-17 | Docker and Tailscale not installed | Info | Phase 7, Phase 11 |
| F-18 | NIC negotiated link speed not captured by the script | Info | Phase 1 (check in the OMV UI) |
| F-19 | `/etc/fstab` comments show the OS disk was `sda` at install and is `sdb` now | Info | — (confirms the by-id / UUID rule) |
| F-20 | Router exposure could not be verified: the router is ISP-managed and the owner has no admin access, so port forwards to the NAS and the UPnP state are unknown | Medium (High if a forward to the NAS exists) | Phase 1 (1.1, 1.11): ask the ISP, decision D-18 |
