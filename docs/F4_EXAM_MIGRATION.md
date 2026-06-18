# F4 — Exam Administration API Migration

**Date:** 2026-06-17  
**Phase:** Production Backend Program **F4**

---

## Overview

F4 makes the server authoritative for exam session lifecycle, marks entry, coordinator verification, approval-gated publish, and published-results reads. Mock mode remains available via `EXAM_API_ENABLED=false`.

---

## Schema

| Migration | Purpose |
|-----------|---------|
| `supabase/migrations/20260618120000_f4_exam_sessions.sql` | `exam_sessions` table; extends `exam_mark_entries` with roster/publish fields |

### `exam_sessions`

- Composite PK `(organization_id, school_id, id)`
- Lifecycle `phase`: `draft` → `scheduled` → `marks_entry` → `processed` → `published`
- Coordinator verification + rejection comment columns
- Probe seed: `exam_math_8a` (class 8-A)

### `exam_mark_entries` extensions

| Column | Purpose |
|--------|---------|
| `student_name`, `roll_number`, `student_code` | Roster display + parent reads |
| `marks_entered` | Distinguishes unentered slots from zero scores |
| `published`, `grade_letter` | Publish workflow |

---

## Edge API

Namespace: `/academics/exams/*`

| Method | Path | Action |
|--------|------|--------|
| GET | `/academics/exams` | List sessions |
| POST | `/academics/exams` | Create draft |
| GET | `/academics/exams/{id}` | Session detail |
| POST | `/academics/exams/{id}/schedule` | Schedule + provision marks |
| POST | `/academics/exams/{id}/open-marks` | Open marks entry |
| GET | `/academics/exams/{id}/marks` | List marks |
| PATCH | `/academics/exams/marks/{markEntryId}` | Update mark |
| POST | `/academics/exams/{id}/process` | Process results |
| POST | `/academics/exams/{id}/verify-coordinator` | Coordinator sign-off |
| POST | `/academics/exams/{id}/publish` | Publish (optional approval guard) |
| GET | `/academics/exams/students/{sisStudentId}/published` | Published results |

Router: `supabase/functions/_shared/academics/exam_administration/exam_administration_router.ts`

---

## F2 approval integration

On `examResults` approval:

- **Approved** → `publishExamResults()` in `approval_type_handlers.ts`
- **Rejected** → `recordExamRejection()` clears coordinator verification

Client: when `APPROVAL_API_ENABLED=true`, `skipDomainEffects` prevents double local publish.

---

## Flutter

| Flag | Provider | Repository |
|------|----------|------------|
| `EXAM_API_ENABLED` | `examApiEnabledProvider` | `ApiExamAdministrationRepository` |

Paths:

- `lib/core/repositories/api/exam_administration/`
- `examAdministrationRepositoryProvider` gated in `repository_providers.dart`

---

## Rollback

1. Set `EXAM_API_ENABLED=false` (mock store + SharedPreferences resume authority)
2. Edge routes remain backward-compatible; no UI removal required

---

## References

- `docs/F4_EXAM_API_ANALYSIS.md`
- `docs/F4_EXAM_API_EXECUTION_PLAN.md`
- `docs/PHASE_F4_FINAL_CERTIFICATION.md`
