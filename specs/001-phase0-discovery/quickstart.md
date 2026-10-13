# Quickstart: running and validating Phase 0 discovery

This guide is for the owner. The assistant never runs anything on the NAS. The contracts are
[contracts/discovery-script.md](contracts/discovery-script.md) and
[contracts/documentation-schema.md](contracts/documentation-schema.md).

## Prerequisites

- **Git Bash** on the PC, not PowerShell (R-02). Work from the repo root.
- Some way to log in to `nas.internal`: root, a sudo account, or the physical console.
- Router admin access.
- The script already extended and reviewed against the allowlist (Stage 1 in the plan).

## 1. Check the script before running it

```bash
file scripts/discovery-readonly.sh          # expect: ... ASCII text (no "CRLF")
grep -nE 'wipefs|mkfs|parted|sgdisk|dd |hdparm|smartctl -[tsoS]|mount|apt (update|install|upgrade)|systemctl (start|stop|restart|enable|disable)|chmod|chown' \
  scripts/discovery-readonly.sh             # expect: no output
mkdir -p discovery-raw
```

## 2. Run it (pick the case that matches your login; R-01)

```bash
D=discovery-raw/discovery-$(date +%F).txt

# B-root
ssh root@nas.internal 'bash -s' < scripts/discovery-readonly.sh > "$D" 2>&1

# B-sudo-nopw
ssh <user>@nas.internal 'sudo bash -s' < scripts/discovery-readonly.sh > "$D" 2>&1

# B-sudo-pw (sudo will ask for your password; type it when prompted)
ssh -t <user>@nas.internal "sudo bash -c \"\$(echo $(base64 -w0 scripts/discovery-readonly.sh) | base64 -d)\"" | tee "$D"
```

Case A (console only): run `sudo bash discovery-readonly.sh | less` on the NAS and write down
the answers. Don't save output on the NAS or on a USB stick.

**Expected:** the file ends with the `Done` section, and `git status` does **not** list it.

```bash
tail -n 2 "$D"
git status --short | grep discovery-raw   # expect: no output
```

## 3. Prove nothing changed (SC-004)

Run the same command again into `discovery-raw/discovery-$(date +%F)-2.txt`, then give both
files to the assistant. The assistant diffs the stable sections, and they must be identical.

## 4. Router checklist

In the router UI (look only, don't change anything), answer every item in
`docs/phase-0-discovery.md` §4 and tell the assistant the answers.

## 5. Validation of the documented result

| Check | Command / action | Expected |
|---|---|---|
| No TBDs left (SC-002) | `grep -c TBD docs/hardware.md docs/network.md` | `0` for each |
| Disks by serial (SC-003) | read the `docs/hardware.md` §2 table | every row has serial + by-id |
| No sensitive identifiers (SC-005) | scan in documentation-schema.md §Pre-commit | no output |
| Questions answered (SC-001) | §5 Results vs §3 questions + §4 checklist | 1:1 coverage |
| Decisions (SC-006) | `docs/decisions.md` summary table | D-01/02/03/04/06/10 DECIDED, or D-06 named as the sole blocker |
| Readability (SC-007) | someone else reads hardware.md | names the Phase 3 disk and its serial/by-id in under 2 min |
| Close-out | `CHANGELOG.md` top entry | says "No changes were made to the server" |

## 6. Commit and push

The assistant makes **local** commits with your Git identity and no AI attribution. You push
manually when you're ready.
