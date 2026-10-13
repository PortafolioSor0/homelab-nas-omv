# Security

Status: **Draft (Phase 0)** — initial threat model; no controls implemented yet.
Last updated: 2026-09-29

## 1. Scope and assumptions

- Single home server on a residential LAN behind a consumer router (NAT).
- Users: owner (admin + data user), relative, possibly other family later.
- Unknown yet (to be confirmed in discovery): router model, whether UPnP is
  enabled, whether any port-forwards already exist, other devices on the LAN
  (IoT/TVs/guests), whether a guest Wi-Fi/VLAN exists.

## 2. Assets

| Asset | Tier | Primary concern |
|---|---|---|
| Personal photos/videos, documents, projects, digital products | 1 | Loss (integrity/availability), confidentiality |
| Relative's private files | 1 | Confidentiality from other users, loss |
| App configs, databases, Compose files, OMV config | 2 | Loss, tampering |
| Media library | 3 | Loss is inconvenient only |
| Admin credentials, SSH keys, Tailscale identity, SMTP creds | — | Compromise = everything above |
| Availability of the NAS itself | — | Family expectations, backups running |

## 3. Threat actors / scenarios

| # | Threat | Likelihood | Impact | Notes |
|---|---|---|---|---|
| T1 | **Hardware failure** (disk, SSD, PSU) | High over years | High | The #1 real-world cause of data loss |
| T2 | **Admin error** (wrong disk wiped, bad chmod, bad sync) | Medium–High | Very high | Includes AI-assisted mistakes → change gates |
| T3 | **Ransomware on a family PC** encrypting SMB shares it can write to | Medium | Very high | Most realistic "attack"; SMB write access = blast radius |
| T4 | Accidental deletion/overwrite by a user | High | Medium–High | Needs versioned backups (ext4 has no snapshots) |
| T5 | Internet attacker against an exposed service | Low **if nothing is exposed**, High otherwise | Very high | Mitigated primarily by not exposing anything |
| T6 | Compromised LAN device (IoT, guest) scanning the LAN | Medium | High | SMB/SSH/OMV UI reachable from whole LAN by default |
| T7 | Compromised container / vulnerable self-hosted app | Medium | Medium–High | Limit mounts, no root, no Docker socket, updates |
| T8 | Malicious or poisoned container image (supply chain) | Low–Medium | High | Official images, pinned versions, review before update |
| T9 | Credential theft (phishing, reused passwords, stolen laptop with SSH key) | Medium | Very high | Unique passwords, passphrase-protected keys, 2FA on Tailscale identity |
| T10 | Physical theft of the server or disks / disk disposal | Low | High (confidentiality) | Encryption at rest decision D-01 |
| T11 | Power loss / surges | Medium | Medium | Filesystem/DB corruption → UPS decision D-13 |
| T12 | Privacy leak between family members (misconfigured share/ACL) | Medium | Medium–High | Per-user shared folders, verification step after every permission change |
| T13 | Silent data corruption (bit rot) | Low | Medium | SMART + SnapRAID scrub + backup verification |
| T14 | Compromise of Tailscale account / coordination plane | Low | High | Strong 2FA on identity provider, ACLs, key expiry, device approval |

## 4. Security objectives

1. No admin interface or file protocol reachable from the public Internet.
2. A compromise of one family device cannot destroy Tier 1 data **and** its backups.
3. Each person can read only their own private data plus explicitly shared areas.
4. Each service can reach only the data it needs, read-only where possible.
5. Every critical failure (disk, backup, sync) produces a notification.
6. The NAS can be rebuilt from this repository + backups.

## 5. Controls mapped to threats

| Control | Threats | Phase |
|---|---|---|
| Change management: show command, verify target by serial/UUID, explicit approval | T2 | all |
| SMART monitoring + scheduled self-tests + notifications | T1, T13 | 2, 12 |
| Versioned, off-site, **pull-based or append-only** backups for Tier 1 | T1, T2, T3, T4, T10 | 13 |
| SnapRAID with deletion threshold before sync | T1, T13 (partly T3) | 14 |
| Least-privilege SMB: per-user shares, read-only where possible, no guest | T3, T6, T12 | 5, 6 |
| SMB hardening: SMB3 minimum, signing, no guest, no SMB1 | T6 | 6 |
| Separate admin account; web UI admin ≠ data user | T9, T2 | 1, 5 |
| SSH keys only, no root login, only admin group allowed | T5, T6, T9 | 1 |
| OMV web UI over HTTPS, session timeout | T6, T9 | 1 |
| Timely security updates (OMV update management) | T5, T7 | 1, ongoing |
| Tailscale with ACLs (owner → all admin ports; relative → SMB only); no port-forwards; UPnP off | T5, T14 | 11 |
| Host firewall (default-deny inbound except required LAN/VPN ports) | T6 | 11 (after VPN is in place; lockout risk) |
| Containers: non-root UIDs, read-only media mounts, no Docker socket, no `privileged`, pinned images | T7, T8 | 7–9 |
| Secrets only in `.env` on server (mode 600), never in Git | T9 | 7 |
| Auth log review / brute-force protection *only if* something is exposed | T5 | 12 (conditional) |
| UPS with automatic clean shutdown (NUT) | T11 | decision D-13 |
| Encryption at rest (LUKS) — **decision needed before formatting** | T10 | 3 |
| Config backups of OMV (`config.xml`, stored off-repo) | T1, T2 | 1, 13 |

### 5.1 Deliberately NOT planned (unless a threat justifies it)

- Fail2ban on SSH/OMV while nothing is exposed publicly: low value, adds
  lockout risk. Re-evaluate if anything becomes Internet-facing.
- IDS/IPS, antivirus on the NAS: no meaningful threat addressed at this scale.
- Reverse proxy: only when a service must be reachable by clients that cannot
  use Tailscale.

## 6. Ransomware-specific note (T3)

This is the scenario most likely to destroy data in a home setup. Mitigations:

- Family PCs only get write access to their **own** areas.
- Media shares are read-only for everyone except the account that manages them.
- Backups must not be writable (deletable) from the NAS's normal SMB users —
  ideally the off-site repository is append-only or immutable (object lock /
  append-only mode), so a compromised NAS cannot delete history.
- SnapRAID `sync` must not blindly run after mass modification (deletion/change
  thresholds).

## 7. Account and credential policy (initial)

- Unique, long passwords generated by a password manager; stored there, never here.
- OMV web `admin` password changed from the default immediately (Phase 1).
- SSH: ed25519 keys with passphrase; password auth disabled after key login is verified.
- Tailscale/identity-provider account: 2FA mandatory.
- Recovery material (LUKS keys if used, backup repo passwords) stored in the
  password manager **and** an offline copy — losing the backup repository
  password makes the backup worthless.

## 8. Open security decisions

See [decisions.md](decisions.md): D-01 (encryption at rest), D-12 (Tailscale placement),
D-13 (UPS), D-14 (Nextcloud or not), D-15 (off-site target).
