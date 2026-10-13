# Research: Phase 0 Read-Only Discovery

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Date**: 2026-09-29

Each item resolves an unknown from the plan's Technical Context. Facts about the operator's PC
were checked on 2026-09-29: Git Bash present, OpenSSH_9.9p2 client, no SSH key pair in
`~/.ssh`, no `nas.internal` host entry in `~/.ssh/config`, `core.autocrlf=true`,
`.gitattributes` = `* text=auto`, and `scripts/discovery-readonly.sh` is LF in both index and
working tree.

---

## R-01 — How the inventory is executed and captured on the PC

**Decision**: Primary method **B (the owner runs it over SSH from the PC, in Git Bash)**. The
exact invocation depends on which account can log in, which only the owner knows:

| Case | Invocation (run by the owner in Git Bash from the repo root) |
|---|---|
| B-root: root may SSH in (OMV has historically allowed this by default) | `ssh root@nas.internal 'bash -s' < scripts/discovery-readonly.sh > discovery-raw/discovery-YYYY-MM-DD.txt 2>&1` |
| B-sudo-nopw: a sudo account with passwordless sudo | same, with `<user>@` and `'sudo bash -s'` |
| B-sudo-pw: a sudo account that needs a password | script passed as an **argument** so stdin/tty stay free for the sudo prompt: `ssh -t <user>@nas.internal "sudo bash -c \"\$(echo $(base64 -w0 scripts/discovery-readonly.sh) \| base64 -d)\"" \| tee discovery-raw/discovery-YYYY-MM-DD.txt` |
| A: no working SSH login | local console: `sudo bash discovery-readonly.sh \| less` — the owner reads it on screen and transcribes the answers. The script is typed or pasted in. **No output file is written on the NAS or a USB stick** (mounting media is a change). |

**Rationale**: FR-002 says the owner executes and the assistant never connects. In B-sudo-pw,
`sudo bash -s` would read the script from stdin, and stdin can't also carry the password prompt.
Passing the script as an argument fixes that without writing any file on the server (FR-001).
Writing the script to `/tmp` on the NAS first was rejected because it writes a file on the
server.

**Alternatives considered**:
- `scp` the script to the NAS, then run it. Rejected: it writes a file on the server.
- `sudo -S` with the password piped in. Rejected: the password would sit in a file or shell
  history on the PC.
- Option C (the assistant runs SSH). Out of scope per spec assumptions and Constitution I.

## R-02 — Windows capture pitfalls

**Decision**: Run the capture in **Git Bash**, not PowerShell. Pin shell scripts to LF by adding
`*.sh text eol=lf` to `.gitattributes`.

**Rationale**:
- In Windows PowerShell 5.1, `>` writes UTF-16LE, and `<` input redirection isn't supported,
  so the documented one-liner fails or produces a file that grep/diff can't handle.
- With `core.autocrlf=true`, a later re-checkout could turn the script to CRLF. `bash -s` on
  the NAS would then fail with `$'\r': command not found`. The file is LF today, but that is
  not guaranteed to last.

**Alternatives considered**: PowerShell with `Get-Content | ssh … | Out-File -Encoding utf8`.
It works but adds friction and is easy to get wrong. Changing the global `core.autocrlf` was
rejected because it isn't this repo's setting to change.

## R-03 — Gaps between the script and the questions in phase-0-discovery.md §3

**Decision**: Extend `scripts/discovery-readonly.sh` with **read-only** commands only
([contracts/discovery-script.md](contracts/discovery-script.md) has the allowlist):

| Gap | Added command | Why it is read-only |
|---|---|---|
| Whole-disk signatures on the 2 TB disk (D-06) beyond the `blkid` cache | `blkid -p -o full <disk>` per disk | low-level probe, reads only |
| Plugin availability for D-01/D-05/D-11 (luksencryption, mergerfs, snapraid, compose, sharerootfs) | `apt-cache policy openmediavault-luksencryption openmediavault-mergerfs openmediavault-snapraid openmediavault-compose openmediavault-sharerootfs` | reads the existing apt cache; no index refresh |
| Number of SATA/ATA ports (expansion) | `ls /sys/class/ata_port` | sysfs listing |
| Time/NTP baseline (Phase 1.3) | `timedatectl` | status only |
| Plain `blkid` can update its cache file (`/run/blkid/blkid.tab`) | change the existing call to `blkid -c /dev/null` | same output, and it doesn't touch the cache file |
| More effective SSH settings | add `permitemptypasswords` and `x11forwarding` to the existing `sshd -T` grep | `sshd -T` only prints config |

Already covered, no change needed: ECC (`dmidecode -t memory`, "Error Correction Type"),
omv-extras (`dpkg-query 'openmediavault-*'` plus the apt sources listing), SSD wear and HDD
sector counts (`smartctl -x`), interface (`lsblk TRAN`), `/dev/dri`.

Deliberately **not** added: `wipefs` (even `--no-act` puts a destructive tool into a script),
`smartctl -t` (starts a test; that's Phase 2), `apt update`, `hdparm` (some options write
settings), `mount`.

**Rationale**: FR-003 needs every question in §3 answered, and edge case 9 allows only
read-only extensions.

## R-04 — Proving "no change to the server" (SC-004)

**Decision**: Use two pieces of evidence.
1. **Static review**: every command in the script is checked against the read-only allowlist
   in [contracts/discovery-script.md](contracts/discovery-script.md) before it runs.
2. **Stable-section diff**: the owner runs the script a second time right after the first
   (same method) and diffs the sections that should not change: `/etc/fstab`, `findmnt`,
   `blkid`, `dpkg-query`, `sshd -T`, `getent`, firewall, apt sources. They must be identical.

**Rationale**: A full-output diff is noisy (`date`, `uptime`, journal, SMART counters), and
the stable sections cover every class of change FR-001 forbids.

**Alternatives considered**: The OMV config-change history. Rejected because it doesn't cover
non-OMV state and is harder to read.

**Side effect to note, not a change**: `smartctl -x` may spin up a disk that is in standby.
That is expected and harmless.

## R-05 — Keeping sensitive identifiers out of Git (FR-004, FR-010, SC-005)

**Decision**: Before every commit in this feature, run a pre-commit **scan** of the staged
diff:
- MAC addresses: `([0-9a-f]{2}:){5}[0-9a-f]{2}` (case-insensitive)
- IPv4 addresses that are not RFC 1918, loopback or documentation ranges
- Secret-like strings: `BEGIN .*PRIVATE KEY`, `\$[0-9a-z]+\$` (hash prefix), `password\s*=`
- Any path under `discovery-raw/`

Private LAN IPs (for example the NAS's `192.168.x.x`) are allowed: `docs/network.md` needs
them, and they aren't secret. Only MACs and public IPs are excluded.

**Rationale**: `.gitignore` already covers `discovery-raw/`, but copying values by hand into
docs is where leaks happen. A scan the assistant can run locally, without touching the NAS,
catches them.

**Alternatives considered**: A git pre-commit hook. Deferred because it changes local repo
tooling and a manual scan is enough for one phase. It can be revisited later.

## R-06 — Where the owner's decisions and router answers are captured

**Decision**: The assistant proposes each decision's final wording in `docs/decisions.md` with
the evidence filled in, and the status changes to DECIDED **only after the owner says so
explicitly** in the session. Router answers are typed by the owner, and the assistant records
them.

**Rationale**: FR-013. Also Constitution Phase-Gated Workflow: never treat PROPOSED as DECIDED.

## R-07 — Handling 2 TB disk contents (D-06)

**Decision**: If `blkid -p`, `fdisk -l` or `lsblk` show **any** partition table or filesystem
signature on the 2 TB disk, D-06 stays OPEN and Phase 0 is reported **not complete**, with
that single blocker named (SC-006). A read-only mount inspection is then proposed as a
separately gated step. It is not executed in this feature.

**Rationale**: Mounting a disk, even read-only, is outside FR-001. The spec's edge cases
already require this.

---

All Technical Context unknowns are resolved. No NEEDS CLARIFICATION remains.
