# Implementation Plan: Phase 0 Read-Only Discovery of nas.internal

**Branch**: `001-phase0-discovery` (spec directory only; work stays on `main`, no git branch created) | **Date**: 2026-09-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-phase0-discovery/spec.md`

## Summary

Finish Phase 0 of `docs/roadmap.md`:
1. Extend the discovery script, using read-only commands only.
2. The owner runs it from the PC over SSH (the assistant never connects).
3. The raw output stays git-ignored.
4. The assistant turns the reviewed output into sanitized docs: `hardware.md`, `network.md`,
   and the Results section of `phase-0-discovery.md`.
5. The owner completes the router checklist.
6. The pre-format decisions are recorded as DECIDED with evidence.
7. Phase 0 closes with a CHANGELOG entry and a stop.

The approach is set in [research.md](research.md): Git Bash capture, argument-passed script for
password sudo, a read-only allowlist, a stable-section diff, and a pre-commit identifier scan.

## Technical Context

**Language/Version**: Bash (the NAS's Debian bash, run by the owner). Markdown for all
deliverables.

**Primary Dependencies**: Tools already on the NAS: util-linux, smartmontools, dmidecode,
pciutils, iproute2, openssh-server, apt, systemd. On the PC: Git Bash and OpenSSH_9.9p2.
Nothing gets installed on the NAS (R-03 records missing tools as gaps).

**Storage**: Raw output in `discovery-raw/` on the PC (git-ignored). Summaries go into `docs/`.

**Testing**: Read-only verification only:
- the allowlist review of the script (R-04)
- a stable-section diff between two runs (R-04)
- a pre-commit identifier scan (R-05)
- `grep -c TBD` on the target docs (SC-002)

**Target Platform**: `nas.internal`, OpenMediaVault 8 on Debian (exact release to be
discovered). The operator PC runs Windows 11 with Git Bash.

**Project Type**: Documentation and configuration-as-code repo. This feature changes one
script and several docs.

**Performance Goals**: Not applicable. One run takes a few minutes; `smartctl -x` on 2 disks
is the slowest part.

**Constraints**:
- Zero server state changes (FR-001).
- The owner executes; the assistant does not connect (FR-002).
- No MAC addresses, public IPs or secrets in Git (FR-010).
- Decisions change status only on explicit owner approval (R-06).

**Scale/Scope**: 1 server, 2 known disks, around 7 docs touched, 1 script, 1 CHANGELOG entry.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Real-Server Safety | No gated operation occurs. The script stays read-only (allowlist in [contracts/discovery-script.md](contracts/discovery-script.md)). `wipefs`, `smartctl -t`, `apt update`, `hdparm` and `mount` are excluded. The owner runs it and the assistant never connects. Nothing touches the OS disk. | ✅ PASS |
| II. Stable Disk Identity | Disk records need model, serial, capacity, by-id and FS UUID; `/dev/sdX` is informational only ([data-model.md](data-model.md) Disk record). | ✅ PASS |
| III. Tiered Data Protection | No data is moved. D-10 is recorded as policy only. | ✅ PASS |
| IV. Least Privilege | Existing accounts are only read (`getent`). No accounts are created or changed. | ✅ PASS |
| V. No Public Admin Exposure | The router check is read-only. Any port forward found becomes a Phase 1 finding and is not changed here. | ✅ PASS |
| VI. OMV-Native Configuration | No configuration is done. The plugin *availability* check is read-only (`apt-cache policy`). | ✅ PASS |
| VII. No Secrets in Git | Raw output stays in `discovery-raw/`. The pre-commit scan (R-05) blocks MACs, public IPs and key/hash patterns. Serials are allowed while the repo is private. | ✅ PASS |
| Documentation & Evidence | Every value is traced to the raw output (US2 scenario 3). Unknowns are written as "unknown — reason". A CHANGELOG entry is written at close. | ✅ PASS |
| Phase-Gated Workflow | Scope is Phase 0 only. The feature ends with a stop until Phase 1 is approved. Commits are local, with the current identity and no AI attribution; the owner pushes. | ✅ PASS |

**Gate result: PASS. No violations.**

**Post-design re-check (after Phase 1 artifacts):** still PASS. The design adds the read-only
commands from R-03 (and makes `blkid` cache-free), one `.gitattributes` line and doc edits. It adds no server-side writes and no new
identifiers in Git.

## Project Structure

### Documentation (this feature)

```text
specs/001-phase0-discovery/
├── spec.md
├── plan.md              # this file
├── research.md          # R-01..R-07
├── data-model.md        # entities, validation, state transitions
├── quickstart.md        # owner/assistant run + validation guide
├── contracts/
│   ├── discovery-script.md      # read-only allowlist + output section contract
│   └── documentation-schema.md  # required fields/format of docs being filled
├── checklists/
│   └── requirements.md
└── tasks.md             # created later by /speckit-tasks
```

### Repository files touched by this feature

```text
.gitattributes                    # + "*.sh text eol=lf"  (R-02)
scripts/discovery-readonly.sh     # + read-only commands   (R-03)
scripts/README.md                 # invocation notes for Git Bash / sudo cases
discovery-raw/                    # raw output, git-ignored, never committed
docs/hardware.md                  # all TBD resolved
docs/network.md                   # all TBD resolved + router answers
docs/phase-0-discovery.md         # §4 router checklist, §5 Results + findings, status
docs/decisions.md                 # D-01/02/03/04/06/10 → DECIDED (owner-approved); D-17 facts
docs/roadmap.md                   # Phase 0 status
README.md                         # "Current status" table refresh
CHANGELOG.md                      # Phase 0 discovery entry
```

**Structure Decision**: There is no source tree. The repository's existing
`docs/` + `scripts/` layout is used as it is. No new top-level directories.

## Execution Stages (for /speckit-tasks)

1. **Prepare**: add `.gitattributes`, extend the script (allowlist review), and update the
   invocation notes. The assistant does this locally and commits it locally.
2. **Run**: the owner runs the script twice using the R-01 case that matches their login, and
   the router checklist. **STOP** until the owner shares the output.
3. **Review**: the assistant reads the raw output, does the stable-section diff, and drafts
   the findings.
4. **Document**: fill in `hardware.md`, `network.md` and the §5 Results, then run the
   identifier scan.
5. **Decide**: the assistant proposes the decision wording with evidence; the owner approves
   each one; update `decisions.md`.
6. **Close**: add the CHANGELOG entry, update the status lines, make a local commit. **STOP**
   until Phase 1 is approved.

## Complexity Tracking

No violations. Nothing to justify.
