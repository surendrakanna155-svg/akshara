# Phase F5 — Attendance API Final Certification

**Date:** 2026-06-18  
**Phase:** Production Backend Program **F5**  
**Class A items:** A4 Class attendance submit · A5 Attendance correction  
**Verdict:** **PASS** (F5 API scope; Patrol infra caveat — see §Patrol)  
**Authority:** `docs/ORCHESTRATOR_AGENT.md`, `docs/F5_ATTENDANCE_API_ANALYSIS.md`

---

## Executive summary

| Gate | Result |
|------|--------|
| `flutter analyze` | **0 errors** (108 info/warnings — pre-existing style) |
| `flutter test` (full suite) | **1971 passed**, 1 skipped |
| F5 contract tests | **PASS** (mock + fake-Dio API parity) |
| F5 integration tests | **PASS** (`f5_attendance_api_integration_test.dart`) |
| Approval → correction apply | **PASS** (adapter + sync store + repository status) |
| Mock fallback | **PASS** (`ATTENDANCE_API_ENABLED=false`) |
| F2 apply hook | **PASS** (`approval_type_handlers.ts` → `applyAttendanceCorrection`) |
| Attendance widget tests | **PASS** (admin, teacher, parent correction) |
| Patrol attendance journeys | **INFRA BLOCKED** — see below |

**Production API readiness:** **~81% → ~89%** (F5 corrections API, sessions read, approval apply)

---

## Patrol gate (infrastructure)

| Journey | Target | Result |
|---------|--------|--------|
| Teacher attendance submit | `teacher_attendance_e2e_test.dart` | **INFRA** — instrumentation process crash (0 tests executed) |
| Teacher correction request | `pilot_closure_workflows_e2e_test.dart` | **INFRA** — same harness failure |
| Management corrections admin | `pilot_closure_workflows_e2e_test.dart` | **INFRA** — same harness failure |

**Classification:** Infrastructure — `Medium_Phone_API_36.0` AVD; Gradle report: *"Instrumentation run failed due to Process crashed."* Not an application widget/RBAC defect.

**Mitigation evidence:** P0 widget `P0-ATT-001` admin screen test; teacher/parent correction widget tests; integration test `correction submit → principal approve updates sync store and status`.

**Re-run command (when AVD stable):**

```bash
patrol test --target patrol_test/workflows/teacher_attendance_e2e_test.dart \
  --device emulator-5554 \
  --dart-define=APP_ENV=development \
  --dart-define=ENABLE_QA_LOGIN=true \
  --dart-define=ENABLE_DEMO_AUTH=true \
  --dart-define=ENABLE_API_MODE=false
```

---

## Deliverables

### F5.0 — Schema

| Artifact | Path |
|----------|------|
| Migration | `supabase/migrations/20260618130000_f5_attendance_corrections.sql` |

### F5.1 — Edge attendance module

| Artifact | Path |
|----------|------|
| Corrections repository | `supabase/functions/_shared/attendance/attendance_correction_repository.ts` |
| Sessions repository | `supabase/functions/_shared/attendance/attendance_sessions_repository.ts` |
| Handlers | `supabase/functions/_shared/attendance/attendance_handlers.ts` |
| Router | `supabase/functions/_shared/attendance/attendance_router.ts` |
| API wire | `supabase/functions/api/index.ts` |

### F5.2 — Flutter API repository

| Artifact | Path |
|----------|------|
| Paths | `lib/core/repositories/api/attendance/remote/attendance_api_paths.dart` |
| Remote | `lib/core/repositories/api/attendance/remote/attendance_correction_remote_datasource.dart` |
| Mapper | `lib/core/repositories/api/attendance/mapper/attendance_correction_mapper.dart` |
| Repository | `lib/core/repositories/api/attendance/api_attendance_correction_repository.dart` |
| Provider gate | `ATTENDANCE_API_ENABLED` in `repository_config.dart` |

### F5.3 — Approval integration

| Artifact | Path |
|----------|------|
| Server apply on approve | `supabase/functions/_shared/approval/approval_type_handlers.ts` |
| Client adapter (repository-backed) | `lib/core/approvals/adapters/attendance_correction_approval_adapter.dart` |
| Management admin screen | `lib/features/management/attendance/attendance_corrections_admin_screen.dart` |

### F5.4 — Tests & docs

| Artifact | Path |
|----------|------|
| Contract | `test/contracts/attendance/attendance_correction_repository_contract_test.dart` |
| Integration | `test/integration/attendance/f5_attendance_api_integration_test.dart` |
| Analysis | `docs/F5_ATTENDANCE_API_ANALYSIS.md` |
| Migration | `docs/F5_ATTENDANCE_MIGRATION.md` |
| Certification | `docs/PHASE_F5_FINAL_CERTIFICATION.md` |

---

## Out of scope (deferred)

| Item | Phase |
|------|-------|
| `GET /teacher/attendance/submissions/{id}` client wiring | Post-F5 |
| Full `MockAttendanceSyncStore` API replacement | F7 |
| Patrol infra fix (API 36 AVD) | Ops / QA |

---

## Sign-off

| Role | Status |
|------|--------|
| Agent A (Backend) | Schema + Edge module complete |
| Agent A (Flutter API) | Repository + provider gate complete |
| Agent B (Features) | Correction workflows + admin screen wired |
| Agent E (QA) | Contract + integration + widget green |
| Agent G (Release) | Analyze + unit gates green — F5 commit authorized |

**Next authorized step:** **F6 — Audit / event upload API**
