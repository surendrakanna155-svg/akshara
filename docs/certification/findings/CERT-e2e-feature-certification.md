# NIKSHA OS — Workstream 2: End-to-End Feature Certification

**Branch** `release/v1.0-playstore` · **Started** 2026-07-29 · **Read-only pass.**

## What "certified end to end" means here

Per the charter, a feature is certified only when traced **first user action → UI →
validation → API → database → audit → notifications → reports → analytics →
dashboards → related modules → final outcome**. This document records, per module,
**which of those twelve links exist and which are absent** — not whether a test
passes.

Link legend used in every module table:

| Symbol | Meaning |
|---|---|
| ✅ | Link exists and carries the real value end to end |
| ⚠️ | Link exists but is partial, wrong, or unreachable for some personas |
| ❌ | Link is absent — nothing on this path performs that step |
| — | Not applicable to this feature |

## Build-on, not re-derive

This workstream **inherits and does not restate**:

- `findings/XMOD-cross-module-certification.md` — 39 defects; the **dead event bus**
  (XMOD-001) and the **31 manual steps** finding are treated as established facts
  and are cited, not re-proved.
- `findings/JOURNEY-role-journeys.md` — 16 defects; role reachability.
- `findings/SIM-real-school.md` — 4 defects; a full school day.
- `findings/WIDGET-dashboard-certification.md` — 18 defects; every dashboard widget.
- `findings/DAI-certification.md` — 16 defects; global search.

Where a link is broken **for a reason another workstream already documented**, this
document marks the link ⚠️/❌ and cites the existing ID. New defects raised here use
the `E2E-` prefix.

## Order of certification

By what a school touches daily and what hurts most if wrong:
attendance · fees/collections · exams & marks · report cards · certificates ·
admissions · leave · payroll · transport · library · hostel · communication ·
inventory · student & staff records.

## Verification boundary for this workstream

Static + contract tracing only. No Postgres lane, no live VPS, no release binary
(charter). "Writes to table X" is proved by reading the repository/handler SQL and
the migration that defines X, never by observing a row. Where a claim could not be
settled from source, it is stated as a boundary rather than a finding.

---
