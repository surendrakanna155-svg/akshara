# F5 — Attendance API Analysis

**Date:** 2026-06-18  
**Phase:** Production Backend Program **F5**  
**Class A items:** A4 Class attendance submit · A5 Attendance correction  
**Authority:** `docs/PRODUCTION_BACKEND_ROADMAP.md`, `docs/ORCHESTRATOR_AGENT.md`

---

## Executive summary

F5 closes Class A gaps **A4** (teacher class attendance submit) and **A5** (attendance correction with principal approval). Teacher draft/submit already flows through `pilot_operations` (`/teacher/attendance/draft|submit`). F5 adds ERP admin session reads, correction CRUD, F2 approval hooks that apply mark updates server-side, and a Flutter `AttendanceCorrectionRepository` gated by `ATTENDANCE_API_ENABLED`.

---

## Gap inventory (pre-F5)

| Gap | Mock state | Server need |
|-----|------------|-------------|
| Correction requests | `AttendanceCorrectionStore` in-memory | `attendance_corrections` table + REST |
| Principal approve → mark apply | `AttendanceCorrectionApprovalAdapter` + `MockAttendanceSyncStore` | `approval_type_handlers` → `applyAttendanceCorrection()` |
| Management corrections inbox | Admin screen reads store | `GET /attendance/corrections` + sessions context |
| Teacher submit status | Local sync store only | Existing `attendance_sessions` via pilot ops (F5.1 partial) |

---

## F5.1 — Teacher attendance (A4)

| Method | Path | Status |
|--------|------|--------|
| `GET` | `/teacher/attendance/classes` | ✅ pilot_operations |
| `GET` | `/teacher/attendance/students` | ✅ pilot_operations |
| `PUT` | `/teacher/attendance/draft` | ✅ pilot_operations |
| `POST` | `/teacher/attendance/submit` | ✅ pilot_operations |
| `GET` | `/teacher/attendance/submissions/{id}` | ⏸ deferred (client not wired) |
| `GET` | `/attendance/sessions` | ✅ F5 Edge module |
| `GET` | `/attendance/sessions/{id}` | ✅ F5 Edge module |

---

## F5.2 — Attendance correction (A5)

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/attendance/corrections` | List corrections (filter by status) |
| `POST` | `/attendance/corrections` | Create correction request |
| `GET` | `/attendance/corrections/{id}` | Detail |
| `PATCH` | `/attendance/corrections/{id}/status` | Status transition |

**Approval entity:** `entityType = attendance_day`, `entityId = correction.id`

**F2 hook:** On `attendanceCorrection` approve → `applyAttendanceCorrection()` updates `attendance_records` for the submitted session matching class + student.

---

## Flutter repository

| Flag | Provider | Implementation |
|------|----------|----------------|
| `ATTENDANCE_API_ENABLED=false` | `attendanceCorrectionRepositoryProvider` | `MockAttendanceCorrectionRepository` → `AttendanceCorrectionStore` |
| `ATTENDANCE_API_ENABLED=true` | same | `ApiAttendanceCorrectionRepository` |

Client adapter: `AttendanceCorrectionApprovalAdapter` — repository-backed status sync on approve/reject; when `APPROVAL_API_ENABLED=true`, `skipDomainEffects` defers mark apply to server.

---

## Test coverage

| Layer | Path |
|-------|------|
| Contract | `test/contracts/attendance/attendance_correction_repository_contract_test.dart` |
| Integration | `test/integration/attendance/f5_attendance_api_integration_test.dart` |
| Widget | `test/features/management/attendance/`, teacher/parent correction tests |

---

## Deferred (post-F5)

- `GET /teacher/attendance/submissions/{id}` client wiring
- Full replacement of `MockAttendanceSyncStore` with API-backed cache (F7)
- Historical attendance import

---

## References

- `docs/F5_ATTENDANCE_MIGRATION.md`
- `docs/PHASE_F5_FINAL_CERTIFICATION.md`
- `supabase/migrations/20260618130000_f5_attendance_corrections.sql`
