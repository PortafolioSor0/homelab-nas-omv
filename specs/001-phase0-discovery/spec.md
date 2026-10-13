# Feature Specification: Phase 0 Read-Only Discovery of nas.internal

**Feature Branch**: `001-phase0-discovery` (spec directory; no git branch was created — no branch hook is configured)

**Created**: 2026-09-29

**Status**: Draft

**Input**: User description: "Complete Phase 0 read-only discovery of nas.internal"

## Context

Phase 0 is the first of 15 phases in `docs/roadmap.md`. The documentation half is done
(`docs/phase-0-discovery.md` §1); what remains is the **on-server inventory**, the
**router check**, filling every `TBD` in the hardware/network docs, and recording the
**pre-format decisions**. The roadmap exit criteria for Phase 0 are: *"Inventory done,
hardware.md filled, pre-format decisions made"*.

The server holds real data and has an OS disk (TOSHIBA KSG60ZMV256G) that must never be
touched. Nothing in this feature changes the server in any way.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Capture a verified inventory of the server without changing it (Priority: P1)

The owner collects a complete, read-only snapshot of the NAS (OS/OMV version, plugins,
CPU/GPU, RAM, disks with model + serial + stable IDs, disk health data, partition and
filesystem state, network configuration, listening services, SSH effective settings,
users/groups, firewall state, pending updates, recent errors). The raw snapshot is stored
only on the owner's PC, outside version control.

**Why this priority**: Every later phase (hardening, SMART, formatting, permissions,
transcoding) depends on these facts. Without them, any proposal is guesswork on a real
server holding real data.

**Independent Test**: The owner runs the inventory once and receives a raw output file
that contains every section listed in `docs/phase-0-discovery.md` §3; the server's state
before and after is identical (no config changed, no files written on the server, no
SMART self-test started).

**Acceptance Scenarios**:

1. **Given** the owner has console or SSH access to the NAS, **When** the owner runs the
   read-only inventory using a method they choose (console, or SSH from their own PC),
   **Then** a raw output file is produced on the owner's PC under the git-ignored raw
   discovery location.
2. **Given** a raw output file exists, **When** it is reviewed, **Then** every question
   in `docs/phase-0-discovery.md` §3 is either answered or explicitly listed as
   "not determinable from inventory" with the reason.
3. **Given** the inventory has run, **When** the repository status is checked, **Then**
   no raw output file, serial dump, MAC address list, or secret appears as a tracked or
   staged file.

---

### User Story 2 - Turn the raw inventory into reviewed, sanitized documentation (Priority: P1)

The raw output is summarized into the repository's documentation: every `TBD` in
`docs/hardware.md` and `docs/network.md` is replaced with a verified value or an explicit
"unknown — reason / how to find out", the Results section of `docs/phase-0-discovery.md`
is filled, and the OS disk and the 2 TB data disk are each identified by model, serial,
capacity, stable device ID and (where a filesystem exists) filesystem UUID.

**Why this priority**: The repository's purpose is that anyone can understand and rebuild
the NAS from it alone. An inventory that lives only on one PC does not meet that goal,
and Phase 3 (formatting) is gated on disks being identified by serial, not `/dev/sdX`.

**Independent Test**: A reader with only the repository can state, for each disk, its
model, serial, capacity, interface, stable ID, current partition/filesystem state and
key health indicators, and can state the server's OS/OMV versions, CPU, RAM, IP
addressing mode and current SSH login policy — without access to the NAS or the raw
output.

**Acceptance Scenarios**:

1. **Given** the reviewed inventory, **When** `docs/hardware.md` is read, **Then** it
   contains no remaining `TBD` values; each former `TBD` is a value or an explicit
   "unknown" with a reason.
2. **Given** the reviewed inventory, **When** the disk table is read, **Then** the OS
   disk is confirmed as the TOSHIBA KSG60ZMV256G by serial and stable ID and is marked
   "never a data disk", and the 2 TB disk is identified by model, serial and stable ID.
3. **Given** the summary is written, **When** it is compared to the raw output, **Then**
   every recorded value matches the raw output exactly (no inferred or assumed values
   presented as facts).
4. **Given** the summary is written, **When** the committed docs are checked, **Then**
   they contain no MAC addresses, public IP addresses, password hashes, keys or other
   secrets.

---

### User Story 3 - Record router exposure state (Priority: P2)

The owner checks the home router (read-only, via its own admin UI) and records the
router make/model, existing port forwards, UPnP/NAT-PMP state, whether the NAS has a
DHCP reservation, its current IP, and whether guest/IoT networks exist.

**Why this priority**: Determines the current external attack surface and is a
precondition for Phase 1 step 1.1 (DHCP reservation, D-18) and Phase 11. Lower than P1
because the NAS inventory is needed first to identify the NAS's IP and MAC.

**Independent Test**: The router checklist in `docs/phase-0-discovery.md` §4 has every
item ticked with a recorded answer, and `docs/network.md` reflects those answers.

**Acceptance Scenarios**:

1. **Given** the owner has router admin access, **When** they complete the router
   checklist, **Then** every item in `docs/phase-0-discovery.md` §4 has an answer.
2. **Given** a port forward to the NAS is found, **When** it is recorded, **Then** it is
   flagged as a security finding for Phase 1 and **not** changed during Phase 0.

---

### User Story 4 - Make and record the pre-format decisions (Priority: P2)

With the inventory as evidence, the owner confirms the contents of the 2 TB disk (D-06)
and moves each pre-format decision (D-01 encryption, D-02 filesystem, D-03 partitioning
& labels, D-04 disk test depth, D-06 disk contents, D-10 Tier 1 migration policy) from
OPEN/PROPOSED to DECIDED in `docs/decisions.md`, with the date and rationale. D-17
(hardware transcoding) is updated with the discovered CPU/iGPU facts (it need not be
decided until Phase 8).

**Why this priority**: The roadmap makes these decisions part of Phase 0's exit criteria
and they gate Phase 3. They depend on the P1 inventory (e.g. D-04 depends on power-on
hours and sector counts; D-06 depends on partition/filesystem signatures).

**Independent Test**: `docs/decisions.md` shows D-01, D-02, D-03, D-04, D-06 and D-10 as
DECIDED, each with a date, the chosen option and the evidence it relied on.

**Acceptance Scenarios**:

1. **Given** the inventory shows the 2 TB disk has no partitions or filesystem
   signatures, **When** the owner confirms nothing on it is needed, **Then** D-06 is
   recorded as DECIDED with the evidence (serial, observed partition state).
2. **Given** the inventory shows partitions or filesystems on the 2 TB disk, **When**
   D-06 is reviewed, **Then** D-06 stays OPEN, and a separate, explicitly approved
   inspection step is proposed — nothing is mounted, formatted or deleted in Phase 0.
3. **Given** SMART data shows high power-on hours or any reallocated/pending/uncorrectable
   sectors on the 2 TB disk, **When** D-04 is decided, **Then** the decision reflects
   that evidence (per the rule already in D-04).

---

### User Story 5 - Close Phase 0 with a change record and stop (Priority: P3)

Once stories 1–4 are complete, Phase 0 is marked done in the roadmap and discovery doc,
a CHANGELOG entry is added using the change-record template, and work stops awaiting
owner approval to start Phase 1.

**Why this priority**: Required by the project's phase-gated workflow, but only
meaningful after the substantive work is done.

**Independent Test**: CHANGELOG has a dated Phase 0 discovery entry stating "no changes
were made to the server"; the discovery doc status reads complete; Phase 1 has not
started.

**Acceptance Scenarios**:

1. **Given** stories 1–4 are complete, **When** Phase 0 is closed, **Then** a CHANGELOG
   entry exists with all template fields filled and states the server was not modified.
2. **Given** Phase 0 is closed, **When** the next step is requested, **Then** Phase 1
   work begins only after explicit owner approval.

---

### Edge Cases

- **Inventory tool missing on the server** (e.g. SMART or hardware-query utility not
  installed): the gap is recorded as "not determinable — tool missing"; installing
  anything is **not** part of Phase 0 (it is a change and belongs to Phase 1/2 with
  approval).
- **Disk behind a USB bridge or controller that hides SMART/serial**: recorded as a
  finding; identification falls back to stable ID + capacity + physical label check by
  the owner.
- **`/dev/sdX` names differ from the docs** (e.g. OS disk is not `sdb` on this boot):
  the docs are corrected; identity is always by serial, never by device name.
- **More disks than expected, or the expected 2 TB disk is absent**: stop, record, and
  ask the owner before any decision is recorded.
- **The 2 TB disk contains partitions/filesystems/data**: D-06 stays OPEN; no mount,
  format or deletion in this phase (see Story 4, scenario 2).
- **The owner cannot log in with privileges** (no sudo-capable account known): use the
  physical console option; do not attempt credential recovery as part of discovery.
- **Inventory reveals risky current state** (root SSH login with password, open port
  forward, failed services): recorded as findings with severity and fed into Phase 1
  planning — not fixed during Phase 0.
- **Raw output accidentally placed in a tracked location**: must be detected before
  commit and moved into the git-ignored location.
- **Inventory needs an extra read-only check not in the current script**: the script may
  be extended only with commands that read state, and the extension is reviewed before
  it is run.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Discovery MUST NOT change server state: no configuration changes, no
  package installs or index refreshes, no files written on the server, no SMART
  self-tests started, no mounts, no partition/filesystem operations.
- **FR-002**: Discovery MUST be executed by the owner (local console or SSH from the
  owner's PC). The assistant MUST NOT connect to the NAS unless the owner explicitly
  authorizes a specific connection method (host, user, key) in the current session.
- **FR-003**: The inventory MUST cover every question listed in
  `docs/phase-0-discovery.md` §3 (OS/OMV/plugins, disk identity and contents, SMART
  health, disk interface, SSD layout and free space, CPU and `/dev/dri`, RAM and ECC,
  IP configuration, listening services, SSH effective config, users/groups, firewall,
  pending updates).
- **FR-004**: Raw inventory output MUST be stored only in the git-ignored raw discovery
  location on the owner's PC and MUST NOT be committed.
- **FR-005**: Every disk MUST be documented by model, serial, capacity, interface,
  stable device ID and (if present) filesystem UUID; the current `/dev/sdX` name MAY be
  noted only as informational.
- **FR-006**: The OS disk MUST be positively confirmed as the TOSHIBA KSG60ZMV256G by
  serial and documented as never a data disk.
- **FR-007**: For the 2 TB disk, the documentation MUST record partition table presence,
  filesystem signatures, mount state, power-on hours, and reallocated / pending /
  uncorrectable sector and interface CRC error counts.
- **FR-008**: For the OS SSD, the documentation MUST record partition layout, free space
  and wear/health indicators (needed for D-11).
- **FR-009**: Every `TBD` in `docs/hardware.md` and `docs/network.md` MUST be replaced by
  a verified value or an explicit "unknown — reason / how to determine".
- **FR-010**: Committed documentation MUST NOT contain MAC addresses, public IP
  addresses, password hashes, keys, tokens or other secrets. (Disk serials are
  permitted per `docs/hardware.md`, with the existing note to redact before any public
  release.)
- **FR-011**: A findings list MUST be produced in the Results section of
  `docs/phase-0-discovery.md`, classifying each security- or reliability-relevant
  observation (e.g. SSH policy, open ports, failed services, disk health) by severity
  and the phase that will address it.
- **FR-012**: The router checklist (`docs/phase-0-discovery.md` §4) MUST be completed by
  the owner, read-only, and reflected in `docs/network.md`.
- **FR-013**: D-01, D-02, D-03, D-04, D-06 and D-10 MUST be recorded as DECIDED by the
  owner with date, chosen option and supporting evidence; D-17 MUST be updated with
  the discovered CPU/iGPU facts. D-06 MUST NOT be marked DECIDED if the inventory shows
  any partition or filesystem on the 2 TB disk until the owner has resolved it.
- **FR-014**: Phase 0 closure MUST add a CHANGELOG entry using
  `docs/templates/change-record.md`, stating explicitly that the server was not
  modified, and update the status lines in `docs/phase-0-discovery.md` and the roadmap.
- **FR-015**: After closure, work MUST stop until the owner explicitly approves starting
  Phase 1.

### Key Entities

- **Raw inventory snapshot**: the unedited output of one read-only discovery run; dated;
  lives only on the owner's PC; contains sensitive identifiers.
- **Disk record**: one physical disk — role, label, model, serial, capacity, interface,
  stable ID, FS UUID, partition/filesystem state, health indicators, notes.
- **Server record**: OS/OMV/kernel versions, plugins, CPU, iGPU, RAM (size, ECC),
  NIC(s) (speed only in Git), board/BIOS where available.
- **Network/exposure record**: IP addressing mode, listening services, SSH effective
  policy, firewall state, router port forwards, UPnP state, DHCP reservation.
- **Finding**: an observation with severity and the phase that addresses it.
- **Decision record**: a D-xx entry with status, date, chosen option, evidence.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the questions in `docs/phase-0-discovery.md` §3 and the router
  checklist in §4 have a recorded answer or an explicit "unknown — reason".
- **SC-002**: 0 `TBD` markers remain in `docs/hardware.md` and `docs/network.md`.
- **SC-003**: 2 of 2 known disks (and any additional disk found) are identified by
  serial and stable ID; 0 disk references in the docs rely on `/dev/sdX` alone.
- **SC-004**: 0 changes to the server: a post-discovery comparison (same read-only
  checks) shows no configuration, mount or package differences attributable to
  discovery.
- **SC-005**: 0 raw output files, MAC addresses or secrets in Git history for this
  feature.
- **SC-006**: 6 of 6 pre-format decisions (D-01, D-02, D-03, D-04, D-06, D-10) are
  DECIDED with evidence — or, if D-06 is blocked by disk contents, Phase 0 is explicitly
  reported as not complete with that single blocker named.
- **SC-007**: A reader with only the repository can answer "which physical disk may be
  formatted in Phase 3, and how is it identified?" correctly in under 2 minutes.

## Assumptions

- The owner runs discovery personally (console or SSH from their PC); the assistant only
  reviews the output the owner shares. Assistant-run SSH (option C) is out of scope
  unless explicitly authorized later in a session.
- The existing `scripts/discovery-readonly.sh` is the baseline inventory; it may be
  extended with read-only commands only.
- The owner has physical access to the NAS and administrative access to the router.
- Disk serial numbers may be committed because the repository is private (existing rule
  in `docs/hardware.md`); MACs and public IPs may not.
- Information not obtainable by software (free SATA ports/drive bays, PSU, UPS) is filled
  by the owner's physical inspection or recorded as unknown with a reason.
- `.specify/memory/constitution.md` is still an unfilled template; the project's
  governing rules are taken from `CLAUDE.md` and `docs/` instead.
- Out of scope: installing tools, enabling SMART, running SMART self-tests (Phase 2),
  any hardening (Phase 1), any disk/share/user change, fixing any finding.
