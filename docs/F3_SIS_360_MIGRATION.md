# F3 — SIS + Student 360 API Migration Guide

**Date:** 2026-06-17  
**Phase:** Production Backend Program **F3**  
**Flag:** `SIS_API_ENABLED` (gates both `sisRepositoryProvider` and `student360RepositoryProvider`)

---

## Overview

F3 makes the Supabase Edge `/sis/*` module the authoritative source for:

- Student registry search and filters
- Student profile (identity, guardians, documents metadata)
- Student 360 dossier aggregates (all UI tabs)
- Communication timeline merge

Mock repositories remain active when `SIS_API_ENABLED=false`.

---

## Schema changes

| Migration | Tables |
|-----------|--------|
| `supabase/migrations/20260617120000_f3_sis_documents_conduct.sql` | `student_documents`, `student_conduct_incidents` |

Probe fixtures seed School A student `a4000000-0000-4000-8000-000000000001`.

---

## New / updated API routes

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/sis/students/{id}/documents` | List document metadata |
| `POST` | `/sis/students/{id}/documents` | Upload document metadata |
| `GET` | `/sis/students/{id}/360` | Student 360 aggregate (accepts UUID or `student_code`) |
| `GET` | `/sis/students/{id}/timeline` | Merged timeline (accepts UUID or `student_code`) |
| `GET` | `/sis/students/{id}` | Profile now includes `documents[]` |

---

## ID crosswalk

Server resolves path identifiers via `resolveStudentId`:

1. UUID (`students.id`)
2. `student_code` (e.g. `STU-001`, `SIS-STU-*`)
3. `admission_number`

Client test helper: `test/helpers/sis_id_crosswalk.dart`.

Registry filter fix: Prospect chip sends `status=inactive` (server DB status); mock mode still filters `SisStudentStatus.prospect` locally.

---

## Rollback

1. Set `SIS_API_ENABLED=false` in environment / feature flags.
2. Flutter reverts to `MockSisRepository` + `MockStudent360Repository`.
3. Schema rollback (if needed): drop `student_documents`, `student_conduct_incidents` in reverse migration order.

No Student 360 UI changes required for rollback.

---

## Verification

```bash
flutter analyze          # 0 errors
flutter test test/contracts/sis/
flutter test test/contracts/student_360/
flutter test test/integration/sis/f3_sis_360_api_integration_test.dart
```

Patrol: `patrol_test/workflows/pilot_closure_workflows_e2e_test.dart` — `pilot: student 360 dossier navigation`.
