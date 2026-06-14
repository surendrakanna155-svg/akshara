# Agent Execution Plan — Autonomous QA v18.7

**Coordinator:** Agent E (QA)  
**Updated:** 13 June 2026

---

## Virtual agents

| Agent | Modules | Ownership paths |
|-------|---------|-----------------|
| **A** | Admissions + SIS | `lib/core/repositories/mock/mock_admissions*`, `lib/features/admissions/`, `lib/features/sis/`, admission integration tests |
| **B** | Fees + Finance | `lib/features/finance/`, finance mock, finance Patrol |
| **C** | HR + Attendance | `lib/features/teacher/`, `lib/features/hr/`, teacher integration/Patrol |
| **D** | Inventory + Transport | `lib/features/inventory/`, `lib/features/transport/` — analysis only until mutation providers exist |
| **E** | QA Coordinator | `patrol_test/`, `test/integration/`, `docs/QA/`, `qa_test_keys.dart` |

---

## Conflict rules

- Only **one agent** modifies a file per cycle.
- Mock store changes: **Agent A** owns admissions mock; **Agent B** owns finance mock.
- `qa_test_keys.dart`: **Agent E** merges; agents propose keys in their module PRs.
- Patrol helpers: **Agent E** owns `patrol_helpers.dart`; module helpers in `patrol_test/helpers/<module>_journey_helpers.dart`.

---

## Cycle 1 (current)

| Step | Agent | Task | Tests |
|------|-------|------|-------|
| 1 | A | `approveAdmission` → sync `ApprovedStudentHandoff` in mock store | integration |
| 2 | A+B | `admission_finance_e2e_integration_test.dart` | `flutter test test/integration/admissions/` |
| 3 | C | `teacher_attendance_e2e_integration_test.dart` | `flutter test test/integration/mobile/` |
| 4 | B | QA keys + `finance_fee_assignment_e2e_test.dart` | patrol finance target |
| 5 | E | Update `autonomous_progress.md`, coverage estimates | module regression |

**No full 17-suite Patrol run until Cycle 1 complete.**

---

## Cycle 2 (planned)

| Step | Agent | Task |
|------|-------|------|
| 1 | A | Extend admission Patrol with optional fee-handoff step |
| 2 | E | Principal RBAC deny Patrol on approval button |
| 3 | B | Document collection UI gap; spike `createCollectionProvider` spec only |
| 4 | D | Inventory procurement integration test (read path) |

---

## Cycle 3+ (to 60% E2E)

- Attendance journey: teacher Patrol write already Full; add integration → ~85% journey score
- Fee journey: assignment Full + collection blocked → cap ~55% until UI ships
- Combined weighted E2E target ~52–58% after Cycle 1–2; 60% requires collection UI or partial Exam scope decision

---

## Regression policy

| After | Run |
|-------|-----|
| Single integration test | `flutter test <file>` |
| Module complete | `flutter test test/integration/<module>/` + `flutter test test/features/<module>/` |
| Patrol module | `patrol test --target patrol_test/workflows/<module>*` |
| 3+ cycles complete | `ERP_COVERAGE_MODE=full qa/patrol/run_erp_coverage.sh` |
