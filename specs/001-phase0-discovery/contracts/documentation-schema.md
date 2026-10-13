# Contract: documentation outputs

These rules define what "filled in" means for each doc this feature touches. The field
definitions are in [../data-model.md](../data-model.md).

## Universal rules

- Every value comes from the raw snapshot or from an owner statement. Nothing is inferred.
- Unknowns are written as `unknown — <reason / how to determine>`, never left as `TBD`.
- Allowed in Git: models, serials, capacities, by-id names, FS UUIDs, private LAN IPs,
  versions. Forbidden: MAC addresses, public IPs, password hashes, keys, tokens.
- Every edited doc gets its `Last updated:` line set to the edit date.

## `docs/hardware.md`

- §1: every row has a value or `unknown — …`.
- §2 disk table: one row per physical disk found, with all columns from the Disk record. The
  OS row keeps "NEVER a data disk. NEVER wipe."
- §3 disk history: one row per disk, `<date> | <serial> | Inventoried in Phase 0 (POH <n> h)`.
- Acceptance: `grep -c TBD docs/hardware.md` → `0`.

## `docs/network.md`

- The "Current" table is filled, including router model, forwards, UPnP and DHCP
  reservation.
- Acceptance: `grep -c TBD docs/network.md` → `0`.

## `docs/phase-0-discovery.md`

- Status line updated as described in the data-model *Phase 0 status*.
- §1 table rows set to Done, with dates.
- §4 router checklist: every box ticked, each with its answer.
- §5 Results contains:
  - the run metadata: date, run method (R-01 case), and the result of the stable-section diff
  - one line per question in §3 with its answer
  - a findings table: `| ID | Observation | Severity | Addressed in |`

## `docs/decisions.md`

- The summary table's status column is updated.
- Each DECIDED entry gains the line:
  `**Decided 2026-MM-DD by owner:** <choice>. Evidence: <facts>.`

## `CHANGELOG.md`

Add a new entry at the top using `docs/templates/change-record.md` with every field filled.
**Change performed** must include: "Read-only inventory. **No changes were made to the
server.**"

## Pre-commit identifier scan (R-05)

Run it against the staged diff. It must return nothing:

```bash
git diff --cached -U0 | grep -iE '([0-9a-f]{2}:){5}[0-9a-f]{2}|BEGIN .*PRIVATE KEY|\$(1|5|6|y|2[aby])\$|password\s*='
git diff --cached --name-only | grep '^discovery-raw/'
```

Separately, review every IPv4 address in the staged diff by eye. Only private ranges (10/8,
172.16/12, 192.168/16) and loopback are allowed.
