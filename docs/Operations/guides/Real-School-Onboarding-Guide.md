# Real-School Onboarding Guide

**Version:** 1.0 (v1.0-rc1)  
**Audience:** NIKSHA OS platform ops + school leadership  
**Feature freeze:** no new product work — execute only documented steps

---

## Overview

Onboarding a first real school follows **seven phases**. Platform team handles Phase 0–1; school admin handles Phases 2–5 with NIKSHA OS support; parents/teachers activate in Phase 6.

| Phase | Owner | Deliverable |
|-------|-------|-------------|
| 0. Production cutover | Platform | Go-Live Checklist signed |
| 1. School provisioning | Platform | School UUID + admin phone live |
| 2. Academic catalog | School admin | Year, classes, sections |
| 3. Staff import | School admin | Teachers + principal committed |
| 4. Student import | School admin | Students + primary parents committed |
| 5. Validation | Akshara QA + school | ONB-* UAT pass |
| 6. Go-live | School + parents | First-Day checklist |

**Detailed checklists:** [`School-Setup-Checklist.md`](../School-Setup-Checklist.md) · [`First-Day-Go-Live-Checklist.md`](../First-Day-Go-Live-Checklist.md)

---

## Phase 0 — Production cutover (platform)

Before any real-school data:

1. Complete [`Go-Live-Checklist.md`](../Go-Live-Checklist.md) sections 1–6.
2. Confirm `AUTH_OTP_DEV_MODE=false` and live SMS on a test handset.
3. Run `./scripts/production_launch_verify.sh` — 213/213 tenant probes.
4. Take pre-go-live backup per [`Backup-Runbook.md`](../Backup-Runbook.md).
5. Identify rollback tag (`v1.0-rc1` or `v1.0-ops-ready`) per [`Rollback-Checklist.md`](../Rollback-Checklist.md).

---

## Phase 1 — School provisioning (platform)

**There is no self-service “Add School” UI in v1.0-rc1.** Platform ops provisions tenant rows (pattern from staging seed):

1. **Organization** — use existing org or insert `organizations` row.
2. **School** — insert `schools` with unique `code` (e.g. `SCH-REAL-001`).
3. **School admin user** — insert `users` with admin `phone` (E.164 or 10-digit).
4. **Memberships** — `school_memberships` with `role = schoolAdmin`, `status = active`.
5. **Hand off to school:** school name, school code, admin phone, ERP URL, mobile app links.

Record the **school UUID** — all imports and logins are scoped to it.

---

## Phase 2 — Academic catalog (school admin)

**Must complete before student CSV import.**

1. ERP → Academic → create academic year (e.g. `2026-27`) → mark **current**.
2. Create every class label the school uses (e.g. `Nursery`, `1`, `5`, `10`).
3. Create sections per class (`A`, `B`, …).
4. **Critical:** CSV `classLabel`, `sectionLabel`, and `academicYear` must match catalog **exactly** (case-sensitive).

Mismatch → preview shows `invalid` rows; nothing commits for those rows.

---

## Phase 3 — Staff import (school admin)

1. Copy [`templates/teacher_import_template.csv`](../templates/teacher_import_template.csv).
2. Fill `displayName`, `phone`, `role` (`teacher` | `principal` | `schoolAdmin`).
3. ERP → SIS → School Onboarding → Teacher import → **Preview** → review errors → **Commit**.
4. Principal and 2 teachers test OTP login (school scope) before student import.

**Order matters:** import staff before students so attendance/timetable assignments can reference teachers.

---

## Phase 4 — Student & parent import (school admin)

1. Copy [`templates/student_import_template.csv`](../templates/student_import_template.csv).
2. Agree admission number scheme (unique per school, e.g. `SCH-2026-0001`).
3. Import in batches of **≤ 50 rows** per job.
4. Preview every batch — fix `invalid` and understand `duplicate` rows before commit.
5. Spot-check 3 students in SIS after first batch.
6. Test parent login for 2 imported phones.
7. Optional: add `studentPhone` for students who will use the **student app** (see [`Parent-Activation-Guide.md`](./Parent-Activation-Guide.md)).

**Primary parents** are created from `parentName` + `parentPhone` on each row. **Secondary guardians** → invites (see [`parent_guardian_guide.md`](../templates/parent_guardian_guide.md)).

---

## Phase 5 — Validation (Akshara + school)

Run [`UAT-Checklist-v1.0-rc1.md`](../UAT-Checklist-v1.0-rc1.md) **Section 7 (ONB-*)** on the real school tenant.

Log defects in [`Pilot-Issue-Tracker.md`](../Pilot-Issue-Tracker.md). **Do not open parent-wide access** until ONB-11 (live SMS) passes.

---

## Phase 6 — Go-live (school)

Execute [`First-Day-Go-Live-Checklist.md`](../First-Day-Go-Live-Checklist.md).

Distribute to end users:

- [`School-Admin-Quick-Start.md`](./School-Admin-Quick-Start.md)
- [`Teacher-Quick-Start.md`](./Teacher-Quick-Start.md)
- [`Parent-Activation-Guide.md`](./Parent-Activation-Guide.md)

---

## CSV data quality rules (avoid import failures)

| Rule | Why |
|------|-----|
| Commas inside name fields | Wrap field in double quotes, e.g. `"Kumar, Ravi"` |
| Phones: 10–15 digits, optional `+` prefix | Invalid phone → row `invalid` |
| One admission number per student | Duplicate → skipped on commit |
| Class/section/year match catalog | Unknown class → `invalid` |
| Save as UTF-8 CSV | Excel “CSV UTF-8” export recommended |
| Remove blank rows at end of file | Can cause empty invalid rows |

---

## Rollback (if bad import committed)

| Job type | Action |
|----------|--------|
| **Student** | ERP onboarding → rollback job, or `POST /onboarding/imports/:id/rollback` |
| **Teacher** | Avoid automated rollback — does not remove memberships; contact platform ops |

See [`Pilot-Onboarding-Runbook.md`](../Pilot-Onboarding-Runbook.md).

---

## Support escalation

| Issue | First action |
|-------|--------------|
| OTP not received | Verify production SMS config; check phone format |
| All rows invalid | Compare class labels to academic catalog |
| Import timeout | Reduce batch to ≤50 rows; retry with fresh login |
| Parent cannot see child | Confirm parent uses **parent** scope login with imported phone |
| Critical platform fault | [`Rollback-Checklist.md`](../Rollback-Checklist.md) |
