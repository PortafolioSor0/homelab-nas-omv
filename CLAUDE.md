# CLAUDE.md

Guidance for AI coding assistants working in this repository.

- This is a **documentation and configuration-as-code repo** for an OpenMediaVault 8 home
  NAS. There is no build or test suite. Correctness means the docs match the phase plan in
  `docs/roadmap.md` and the decisions in `docs/decisions.md`. When docs disagree, those two win.
- This is a **sanitized public copy**. All identifiers (users, serials, UUIDs, fingerprints,
  IPs) are fake. Never add real ones, secrets, `.env` files or OMV `config.xml` exports.
- Work one phase at a time: inspect → explain → propose → risks → exact commands → approval →
  change → verify → document (`CHANGELOG.md`, template in `docs/templates/change-record.md`).
- Destructive storage, permission, firewall or network changes need the full gate: show the
  exact command, identify the disk by model + serial + UUID (never `/dev/sdX`), state the risk,
  get explicit approval, then verify and document.
- Databases and app state belong on the OS SSD, never on the HDD/mergerfs pool.
- `scripts/discovery-readonly.sh` must stay strictly read-only.
