# Network

Status: **Phase 0 inventory recorded (2026-09-29); updated for Phase 1 (static IP, SSH hardening)**.
Router details unknown (ISP-managed, no admin access).
Last updated: 2026-09-30

## Current (Phase 0 inventory 2026-09-29, updated 2026-09-30)

| Item | Value |
|---|---|
| Hostname / DNS name | Static hostname `nas`; NAS resolver search domain `internal`. Intended name `nas.internal` (`.internal` is reserved for private use) does **not** resolve from the operator PC (`Could not resolve hostname`); the PC's DNS suffix is `lan`. **`nas.local` resolves to `192.168.10.250` through mDNS (avahi)** from the operator PC (2026-09-30) |
| IP addressing mode | **Static** (set in OMV Network → Interfaces, 2026-09-30, D-18) on `enp0s31f6`. Was DHCP `192.168.10.108` until then |
| NAS LAN IP | `192.168.10.250/24` (static) |
| Gateway | `192.168.10.1` |
| DNS | `192.168.10.1` (router), via systemd-resolved |
| Other interfaces | `wlp0s20f3` (Wi-Fi) down; `wpa_supplicant` service running |
| Addressing plan | Static IP in OMV (D-18 DECIDED). `.250` was chosen high to stay away from the router's DHCP pool, whose range is unknown (observed leases `.108`, `.123`). **Residual risk:** an IP conflict if the router ever leases `.250`. If the NAS becomes unreachable, check for a conflict first |
| Router | ISP-managed at `192.168.10.1`; owner has **no admin access** (2026-09-29). Model, UPnP state and port forwards: unknown — ask the ISP (finding F-20, Phase 1 steps 1.1 and 1.11) |
| Internet reachability | **Behind ISP CGNAT** (tracert hop 2 `100.64.12.1`, in `100.64.0.0/10`, 2026-09-30). No public IPv4 on the router and no global IPv6 on the LAN (ULA `fdxx:…` only), so inbound from the internet is not possible. Port forwards and UPnP therefore have no inbound effect (accepted, Phase 1.11). **Re-check if the ISP assigns a public IPv4 or IPv6** |
| Segments | Single flat LAN `192.168.10.0/24` observed; guest/IoT network unknown — no router access, ask the ISP |

## Current listening services (`ss -tulpn`, 2026-09-29)

| Port | Proto | Bound to | Process | Note |
|---|---|---|---|---|
| 22 | tcp | all IPv4 + IPv6 | `sshd` | SSH |
| 80 | tcp | all IPv4 (no IPv6 listener seen 2026-10-03) | `nginx` | OMV web UI, redirects to HTTPS (Force SSL, Phase 1.8) |
| 443 | tcp | all IPv4 (no IPv6 listener seen 2026-10-03) | `nginx` | OMV web UI (HTTPS, self-signed, since Phase 1.8, 2026-09-30) |
| 445 | tcp | all IPv4 + IPv6 | `smbd` | SMB3 only (min protocol SMB3, `smb ports = 445`, NetBIOS off; 139 closed), since Phase 6 (2026-10-03). Shares: `private-alex`, `private-sam`, `shared-family`, `media`. LAN only (CGNAT) |
| 111 | tcp + udp | all IPv4 + IPv6 | `rpcbind` | RPC portmapper (NFS helper); no NFS share configured. Accepted risk until the Phase 11 firewall (1.9) |
| 5355 | tcp + udp | all IPv4 + IPv6 | `systemd-resolved` | LLMNR name resolution |
| 5353 + one ephemeral port | udp | all IPv4 | `avahi-daemon` | mDNS / DNS-SD |
| 5357 | tcp | `192.168.10.250` only | `python3` (`wsdd`) | WS-Discovery so Windows lists the NAS under Network; came with SMB (Phase 6). Seen 2026-10-03 |
| 8096 | tcp | `192.168.10.250` only | `docker-proxy` → Jellyfin | Jellyfin HTTP, LAN only, since Phase 8.4 (2026-10-06) |
| 25 | tcp | 127.0.0.1 only | `master` (Postfix) | Local mail relay for OMV notifications; not reachable from the LAN. Seen 2026-10-03 |
| 53 | tcp + udp | 127.0.0.53, 127.0.0.54 only | `systemd-resolved` | local stub resolver |
| 323 | udp | localhost only | `chronyd` | NTP control socket |

## Current SSH effective policy (`sshd -T`, after Phase 1.7, 2026-09-29)

| Setting | Value |
|---|---|
| port / listen | 22 on `0.0.0.0` and `[::]` |
| permitrootlogin | no |
| passwordauthentication | no |
| pubkeyauthentication | yes |
| kbdinteractiveauthentication | no |
| permitemptypasswords | no |
| x11forwarding | no (via `Match all` in OMV Extra options; check with `sshd -T -C user=…,host=…,addr=…`) |
| allowusers | not set |
| allowgroups | `root`, `_ssh` (members: `owner-admin`) |
| Login method | `owner-admin` + ed25519 key only; admin tasks via `sudo` |

## Current firewall state

No host firewall is active: `nft list ruleset` is empty and `iptables` has policy ACCEPT on
INPUT/FORWARD/OUTPUT with **0 rules**. (Host firewall is planned for Phase 11.)

## Exposure policy

- **No router port-forwards** to the NAS. **UPnP disabled.**
- Never exposed publicly: OMV UI, SSH, SMB, NFS, databases, Docker API.
- Remote access via Tailscale (Phase 11). See [security.md](security.md) §5 and
  [architecture.md](architecture.md) §6.

## Listening services (expected after the relevant phases)

| Port | Service | Reachable from |
|---|---|---|
| 22/tcp | SSH (keys only) | LAN, later tailnet |
| 443/tcp (80 → redirect) | OMV web UI | LAN, later tailnet |
| 445/tcp | SMB (Phase 6) | LAN, later tailnet (ACL-limited) |
| 8096/tcp | Jellyfin (Phase 8) | LAN, tailnet |
| 2283/tcp | Immich (Phase 9) | LAN, tailnet |
