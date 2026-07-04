# F5 — Attendance API Migration

**Date:** 2026-06-18  
**Phase:** Production Backend Program **F5**

---

## Overview

F5 makes the server authoritative for attendance correction requests, session reads for ERP admin, and approval-gated mark application. Teacher class submit remains on existing pilot operations paths. Mock mode stays available via `ATTENDANCE_API_ENABLED=false`.

---

## Schema

| Migration | Purpose |
|-----------|---------|
| `supabase/migrations/20260618130000_f5_attendance_corrections.sql` | `attendance_corrections` table + RLS |

### `attendance_corrections`

- Composite PK `(organization_id, school_id, id)`
- Links to `sis_student_id`, class/section labels, from/to marks, requester metadata
- Status: `pending` → `approved` | `rejected` | `cancelled`
- `present_delta` for aggregate KPI adjustments

---

## Edge API

Namespace: `/attendance/*`

| Method | Path | Action |
|--------|------|--------|
| GET | `/attendance/sessions` | List submitted sessions (ERP admin) |
| GET | `/attendance/sessions/{id}` | Session detail |
| GET | `/attendance/corrections` | List corrections |
| POST | `/attendance/corrections` | Create correction |
| GET | `/attendance/corrections/{id}` | Detail |
| PATCH | `/attendance/corrections/{id}/status` | Update status |

Router: `supabase/functions/_shared/attendance/attendance_router.ts`  
Wire: `supabase/functions/api/index.ts` → `routeAttendance`

---

## F2 approval integration

On `attendanceCorrection` approval:

- **Approved** → `applyAttendanceCorrection()` in `approval_type_handlers.ts`
- **Rejected** → `updateAttendanceCorrectionStatus('rejected')`

Client: when `APPROVAL_API_ENABLED=true`, local adapter skips duplicate mark apply (`skipDomainEffects`).

---

## Flutter

| Flag | Provider | Repository |
|------|----------|------------|
| `ATTENDANCE_API_ENABLED` | `attendanceApiEnabledProvider` | `ApiAttendanceCorrectionRepository` |

Paths:

- `lib/core/repositories/api/attendance/`
- `attendanceCorrectionRepositoryProvider` in `repository_providers.dart`
- `AttendanceCorrectionApprovalAdapter` — repository-backed status sync

Management UI: `lib/features/management/attendance/attendance_corrections_admin_screen.dart`

---

## Rollback

1. Set `ATTENDANCE_API_ENABLED=false` (mock store authority)
2. Set `APPROVAL_API_ENABLED=false` if approval API unstable
3. Edge routes remain backward-compatible; no UI removal required

---

## References

- `docs/F5_ATTENDANCE_API_ANALYSIS.md`
- `docs/PHASE_F5_FINAL_CERTIFICATION.md`
