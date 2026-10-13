---

description: "Task list for Phase 0 read-only discovery of nas.internal"
---

# Tasks: Phase 0 Read-Only Discovery of nas.internal

**Input**: Design documents from `specs/001-phase0-discovery/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: The spec asks for no automated tests. Verification is read-only, as the constitution
defines it (allowlist review, stable-section diff, identifier scan, `grep -c TBD`). Those checks
appear as tasks inside each phase.

**Organization**: Tasks are grouped by user story. Stages from plan.md map to phases:
Prepare → Phase 1–2, Run → US1, Review/Document → US2, Router → US3, Decide → US4, Close → US5.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: user story from spec.md (US1–US5)
- **OWNER**: the task is done by the owner, not the assistant. The assistant MUST stop and wait
  for the owner's result, and MUST NOT connect to the NAS (Constitution I, FR-002).

## Rules for every task

- Nothing in this feature changes the server (FR-001). If a task seems to need a server change,
  stop and ask.
- Commits are **local only**, made with the configured Git identity, with **no AI
  attribution**. **Never `git push`.** The owner pushes manually (CLAUDE.md).
- Run the identifier scan from `contracts/documentation-schema.md` §Pre-commit before every
  commit. Its output must be empty.
- Raw output lives only in `discovery-raw/` (git-ignored). Never copy a MAC address or a
  public IP into a tracked file.

---

## Phase 1: Setup

**Purpose**: Make sure the script survives Windows checkouts (R-02).

- [X] T001 Append the line `*.sh text eol=lf` to `.gitattributes`, keeping the existing `* text=auto` line
- [X] T002 Verify `git ls-files --eol scripts/discovery-readonly.sh` reports `i/lf w/lf` and `file scripts/discovery-readonly.sh` does not mention CRLF

---

## Phase 2: Foundational (the script must be ready before the owner runs it)

**Purpose**: Extend `scripts/discovery-readonly.sh` with read-only commands only (R-03), review
it against `contracts/discovery-script.md`, and update the run instructions.

**⚠️ CRITICAL**: US1 cannot start until this phase is done and committed.

- [X] T003 In `scripts/discovery-readonly.sh` "Identity / OS" section, add `run timedatectl` after `run uptime`
- [X] T004 In `scripts/discovery-readonly.sh` "PCI devices" section, add `run ls /sys/class/ata_port` after `run ls -l /dev/dri`
- [X] T005 In `scripts/discovery-readonly.sh` "Block devices" section, replace `run blkid` with `run blkid -c /dev/null` (so the `/run` cache is never written), and after it add a loop over `lsblk -dn -o NAME,TYPE` disks running `run blkid -p -o full "$dev"`
- [X] T006 In `scripts/discovery-readonly.sh`, add a new section `section "OMV plugin availability"` right after the SMART section, running `run apt-cache policy openmediavault-luksencryption openmediavault-mergerfs openmediavault-snapraid openmediavault-compose openmediavault-sharerootfs`. Never add `apt update`.
- [X] T007 In `scripts/discovery-readonly.sh` "SSH effective config" section, extend the `grep -Ei` pattern to include `permitemptypasswords` and `x11forwarding`
- [X] T008 Review `scripts/discovery-readonly.sh`:
  - (a) `bash -n scripts/discovery-readonly.sh` reports no syntax errors.
  - (b) The forbidden-command grep from `quickstart.md` §1 returns no output.
  - (c) Every command in the script appears in the allowlist in `contracts/discovery-script.md`.
  - (d) Section headers match the "Output sections" order in `contracts/discovery-script.md`.
  - Record the result in the commit message.
- [X] T009 [P] Rewrite the invocation notes in `scripts/README.md` for the R-01 cases (B-root, B-sudo-nopw, B-sudo-pw, A). State that they must run in Git Bash, not PowerShell, and that nothing is written on the NAS. Copy the commands exactly from `quickstart.md` §2.
- [X] T010 [P] Update `docs/phase-0-discovery.md` §2 "How to run the inventory". Replace the single option-B one-liner with the four R-01 cases, add the Git Bash note, and link to `specs/001-phase0-discovery/quickstart.md`. Keep option C wording: "only if you explicitly authorize a specific connection method".
- [X] T011 Run the identifier scan, then make a local commit of `.gitattributes`, `scripts/discovery-readonly.sh`, `scripts/README.md` and `docs/phase-0-discovery.md` with the message `phase0: extend read-only discovery script and run instructions`. Use no AI attribution, and do not push.

**Checkpoint**: the script is ready. Tell the owner: "script ready; see quickstart.md §1–§3".

---

## Phase 3: User Story 1 - Capture a verified inventory without changing the server (Priority: P1) 🎯 MVP

**Goal**: A complete raw snapshot on the owner's PC, plus proof that the server did not change.

**Independent Test**: The raw file contains every section in `contracts/discovery-script.md` and
ends with `Done`. `git status` does not list it. The stable-section diff between run 1 and run 2
is empty.

- [X] T012 [US1] **OWNER**: follow `quickstart.md` §1–§2. Pick the R-01 case that matches your login and write the output to `discovery-raw/discovery-YYYY-MM-DD.txt`. **Assistant: STOP until the owner confirms the file exists.**
- [X] T013 [US1] **OWNER**: follow `quickstart.md` §3. Run the same case again into `discovery-raw/discovery-YYYY-MM-DD-2.txt` and tell the assistant which R-01 case was used.
- [X] T014 [US1] Check completeness of `discovery-raw/discovery-YYYY-MM-DD.txt`:
  - Every section header from `contracts/discovery-script.md` is present, and the file ends with `==================== Done ====================`.
  - Any "not installed" / "command not found" lines are listed as gaps.
  - `git status --short` shows no `discovery-raw/` path.
  - If the Done marker is missing, ask the owner to rerun T012.
- [X] T015 [US1] Diff only the stable sections (`/etc/fstab`, `findmnt`, `blkid`, `dpkg-query`, SSH effective config, Users and groups, APT sources, Firewall state) between `discovery-raw/discovery-YYYY-MM-DD.txt` and `discovery-raw/discovery-YYYY-MM-DD-2.txt`. They must be identical. Record the result for T021.
- [X] T016 [US1] Build a coverage matrix in `discovery-raw/review-notes-YYYY-MM-DD.md` (git-ignored). Each question in `docs/phase-0-discovery.md` §3 gets its answer, or "not determinable from inventory — reason".
- [X] T017 [US1] Check the disk-count edge case in `discovery-raw/review-notes-YYYY-MM-DD.md`:
  - Data-model rule: "A disk count different from 2, or a missing 2 TB disk, sets `role = unexpected` and blocks Stage 5".
  - Confirm the OS disk model string is exactly `TOSHIBA KSG60ZMV256G`.
  - If either check fails, **STOP and ask the owner** before continuing.

**Checkpoint**: US1 is complete. The inventory exists, is complete, is untracked, and the server
did not change.

---

## Phase 4: User Story 2 - Turn the raw inventory into sanitized documentation (Priority: P1)

**Goal**: A reader with only the repo knows every disk and the server's key facts. No TBDs remain in
`docs/hardware.md`.

**Independent Test**:
- `grep -c TBD docs/hardware.md` → `0`.
- Every disk row has model, serial, capacity, interface, by-id and FS UUID/"none".
- Every value matches the raw file.
- The identifier scan is empty.

- [X] T018 [P] [US2] Fill `docs/hardware.md` §1 (Server record):
  - Record OS/Debian release, OMV version, kernel, installed OMV plugins, omv-extras (yes/no), board/BIOS, CPU, iGPU + `/dev/dri`, RAM size, ECC, NIC model + speed, and ATA port count.
  - Items software can't see (free bays, PSU, UPS) are filled from the owner's answer or `unknown — reason`.
  - Rule: "never record a MAC address. NIC is recorded as model and speed only."
- [X] T019 [US2] Fill `docs/hardware.md` §2 with one Disk record per physical disk:
  - Record role, model, serial, capacity (TB and TiB), interface, by-id (ata-… preferred), FS UUID or "none", partition state, mount state, and health.
  - Health fields: power-on hours, reallocated, pending, offline-uncorrectable, UDMA CRC errors; for the SSD also wear/percentage used and available spare.
  - Rules to apply: "serial … MUST match between `lsblk` and `smartctl`"; "The OS record MUST have model `TOSHIBA KSG60ZMV256G` and be marked 'NEVER a data disk'"; `/dev/sdX` is "informational only".
- [X] T020 [US2] Add one row per disk to `docs/hardware.md` §3 "Disk history": `<date> | <serial> | Inventoried in Phase 0 (POH <n> h)`
- [X] T021 [P] [US2] Fill the non-router rows of the "Current" table in `docs/network.md`:
  - Record IP addressing mode (DHCP/static), NAS LAN IP (private range only), gateway, and DNS.
  - Add a "Current listening services" table (port/proto/process) from `ss -tulpn`.
  - Add the SSH effective policy (`permitrootlogin`, `passwordauthentication`, `pubkeyauthentication`, `kbdinteractiveauthentication`, `permitemptypasswords`, allow users/groups).
  - Add firewall presence and rule count.
  - Leave the router rows for US3.
- [X] T022 [US2] Write the first part of `docs/phase-0-discovery.md` §5 "Results": run metadata (date, R-01 case, the T015 stable-diff result) and one line per §3 question with its answer, taken from `discovery-raw/review-notes-YYYY-MM-DD.md`
- [X] T023 [US2] Add a findings table `| ID | Observation | Severity | Addressed in |` to `docs/phase-0-discovery.md` §5:
  - IDs run F-01, F-02, …; severity is High/Medium/Low/Info.
  - Cover the SSH policy, listening services, failed services, pending updates, disk health, missing tools and firewall.
  - Findings are never fixed in Phase 0.
- [X] T024 [US2] Traceability check: compare every value written in T018–T023 against the raw file, and correct any value that isn't literally supported. Then confirm `grep -c TBD docs/hardware.md` → `0`.
- [X] T025 [US2] Run the identifier scan, review any IPv4 addresses by eye, then make a local commit of `docs/hardware.md`, `docs/network.md` and `docs/phase-0-discovery.md` with the message `phase0: document read-only inventory results`. Use no AI attribution, and do not push.

**Checkpoint**: US1 + US2 make up the MVP. The inventory is captured and documented.

---

## Phase 5: User Story 3 - Record router exposure state (Priority: P2)

**Goal**: The router checklist is answered and `docs/network.md` has no TBDs.

**Independent Test**: every §4 item is ticked with an answer, and `grep -c TBD docs/network.md`
→ `0`.

- [X] T026 [US3] **OWNER**: in the router UI (read-only), answer the `docs/phase-0-discovery.md` §4 items: router make/model, port forwards, UPnP/NAT-PMP, NAS DHCP reservation + current IP, guest/IoT network. **Assistant: STOP until the owner gives the answers.** The assistant does not change anything on the router.
- [X] T027 [US3] Tick every box in `docs/phase-0-discovery.md` §4 and write the owner's answer next to each one
- [X] T028 [US3] Fill the router, segments and addressing rows in `docs/network.md`. If any port forward to the NAS exists, or UPnP is on, add it to the findings table in `docs/phase-0-discovery.md` §5 as High severity, "Addressed in: Phase 1". Do not change it now.
- [X] T029 [US3] Confirm `grep -c TBD docs/network.md` → `0`, run the identifier scan, then make a local commit with the message `phase0: record router exposure state`. Use no AI attribution, and do not push.

---

## Phase 6: User Story 4 - Make and record the pre-format decisions (Priority: P2)

**Goal**: D-01, D-02, D-03, D-04, D-06 and D-10 are DECIDED with evidence, or D-06 is named as the
only blocker.

**Independent Test**: the summary table in `docs/decisions.md` shows those six as DECIDED, and each
has a `**Decided YYYY-MM-DD by owner:**` line with evidence.

- [X] T030 [US4] Evaluate D-06 with R-07 using the `blkid -p`, `fdisk -l` and `lsblk` output for the 2 TB disk. If **any** partition table or FS signature exists, D-06 stays OPEN: record "Phase 0 blocked: D-06" in `docs/phase-0-discovery.md` status and **STOP**. Propose the read-only inspection as a separately gated step, and do not run it.
- [X] T031 [US4] Draft proposals for `docs/decisions.md` **in chat** (do not write them to the file yet) for each decision:
  - **D-01:** use the `apt-cache policy openmediavault-luksencryption` result.
  - **D-02 and D-03:** give the proposed choice.
  - **D-04:** apply its rule to the POH and reallocated/pending/uncorrectable counts.
  - **D-06:** cite the serial and the observed empty state.
  - **D-10:** give the policy wording.
  - Each proposal shows the choice and the evidence.
- [X] T032 [US4] **OWNER**: explicitly approve or amend, for `docs/decisions.md`, each of D-01, D-02, D-03, D-04, D-06 and D-10 in the session. Rule: "`PROPOSED → DECIDED`: **only** on explicit owner approval".
- [X] T033 [US4] Update `docs/decisions.md`:
  - Set the summary-table status to DECIDED **only for the decisions the owner approved**.
  - Append `**Decided YYYY-MM-DD by owner:** <choice>. Evidence: <facts>.` under each approved decision.
  - Update the `Last updated:` line.
- [X] T034 [US4] Update D-17 in `docs/decisions.md` with the discovered CPU/iGPU and `/dev/dri` facts. The status stays OPEN (it is decided in Phase 8).
- [X] T035 [US4] Run the identifier scan, then make a local commit of `docs/decisions.md` with the message `phase0: record pre-format decisions`. Use no AI attribution, and do not push.

---

## Phase 7: User Story 5 - Close Phase 0 and stop (Priority: P3)

**Goal**: Phase 0 is recorded as complete, and work stops until Phase 1 is approved.

**Independent Test**: the top entry in `CHANGELOG.md` says "No changes were made to the server",
the status lines say Phase 0 is complete, and Phase 1 has not started.

- [X] T036 [US5] Add a new entry at the top of `CHANGELOG.md` using `docs/templates/change-record.md`:
  - Title: `YYYY-MM-DD — Phase 0: read-only discovery`.
  - Fill every field.
  - **Change performed** includes: "Read-only inventory. **No changes were made to the server.**"
  - List the docs updated.
- [X] T037 [P] [US5] Set Phase 0 to "Complete (awaiting Phase 1 approval)" in the status line and §1 table of `docs/phase-0-discovery.md` (all rows Done, with dates)
- [X] T038 [P] [US5] Mark Phase 0 complete in `docs/roadmap.md` and update its `Last updated:` line
- [X] T039 [P] [US5] Update the "Current status" table in `README.md` with verified values: OS/OMV version, the 2 TB disk state, and "Current phase: Phase 0 complete — awaiting Phase 1 approval"

---

## Phase 8: Polish & Final Validation

- [X] T040 Run every row of the validation table in `quickstart.md` §5 (SC-001 … SC-007 and close-out), and fix any doc that fails
- [X] T041 Run the identifier scan, confirm `git status` shows only files relevant to this feature, then make a local commit of `CHANGELOG.md`, `docs/phase-0-discovery.md`, `docs/roadmap.md` and `README.md` with the message `phase0: close Phase 0 (no server changes)`. Use no AI attribution, and **do not push**.
- [X] T042 **STOP**. Tell the owner that Phase 0 is complete and the commits are local and ready to push. Summarize the findings that feed Phase 1, and wait for explicit approval before any Phase 1 work (`specs/001-phase0-discovery/spec.md` FR-015).

---

## Dependencies & Execution Order

- **Setup (T001–T002)** → **Foundational (T003–T011)** → **US1 (T012–T017)**
- **US1** → **US2 (T018–T025)**: US2 needs the raw file.
- **US3 (T026–T029)** can run in parallel with US2 once US1 is done. It needs the NAS IP from US1.
  T028 appends to the findings table, so do it after T023.
- **US4 (T030–T035)** needs US2 (the disk evidence). T030 can block the rest of US4 and all of
  US5.
- **US5 (T036–T039)** needs US2, US3 and US4.
- **Polish (T040–T042)** comes last.

Owner gates (hard stops): T012, T013, T026, T032, T042.

## Parallel Opportunities

- Foundational: T009 ∥ T010. They touch different files, after T003–T008.
- US2: T018 (hardware.md §1) ∥ T021 (network.md). T019–T020 follow T018 in the same file.
- US2 ∥ US3: the owner can do the router check (T026) while the assistant documents (T018–T024).
- US5: T037 ∥ T038 ∥ T039. They touch different files.

## Implementation Strategy

**MVP = Setup + Foundational + US1 + US2.** At that point the real server is inventoried and
documented by serial, which is the most valuable and least reversible knowledge. Then US3 (router),
US4 (decisions, which need the owner), and US5 (closure). Each story ends with its own local commit,
so progress is checkpointed and the owner can push at any point.
