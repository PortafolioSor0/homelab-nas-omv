# scripts/

| Script | Purpose | Modifies server? |
|---|---|---|
| `discovery-readonly.sh` | Phase 0 inventory (hardware, disks, SMART data, OMV plugin availability, network, services, users) | **No** — read-only |

Rule: any script that changes state must say so at the top, support a dry-run,
and require explicit approval before being run on the NAS.

## Running `discovery-readonly.sh`

- Run these commands in **Git Bash** from the repo root, **not PowerShell**.
  PowerShell's `<` redirection and quoting break the commands below.
- The script is streamed over SSH, and its output is saved **on your PC** under
  `discovery-raw/` (git-ignored). **Nothing is written on the NAS**: no copy of the
  script, no output file.
- The allowed commands are listed in
  [specs/001-phase0-discovery/contracts/discovery-script.md](../specs/001-phase0-discovery/contracts/discovery-script.md).
  The full guide is [specs/001-phase0-discovery/quickstart.md](../specs/001-phase0-discovery/quickstart.md).

Check the script first:

```bash
file scripts/discovery-readonly.sh          # expect: ... ASCII text (no "CRLF")
grep -nE 'wipefs|mkfs|parted|sgdisk|dd |hdparm|smartctl -[tsoS]|mount|apt (update|install|upgrade)|systemctl (start|stop|restart|enable|disable)|chmod|chown' \
  scripts/discovery-readonly.sh             # expect: no output
mkdir -p discovery-raw
```

Then pick the case that matches how you log in:

```bash
D=discovery-raw/discovery-$(date +%F).txt

# B-root
ssh root@nas.internal 'bash -s' < scripts/discovery-readonly.sh > "$D" 2>&1

# B-sudo-nopw
ssh <user>@nas.internal 'sudo bash -s' < scripts/discovery-readonly.sh > "$D" 2>&1

# B-sudo-pw (sudo will ask for your password; type it when prompted)
ssh -t <user>@nas.internal "sudo bash -c \"\$(echo $(base64 -w0 scripts/discovery-readonly.sh) | base64 -d)\"" | tee "$D"
```

- **A (console only)**: run `sudo bash discovery-readonly.sh | less` on the NAS and
  write down the answers. Don't save output on the NAS or on a USB stick.

The run is complete when the file ends with the `Done` section, and `git status`
must not list it:

```bash
tail -n 2 "$D"
git status --short | grep discovery-raw   # expect: no output
```
