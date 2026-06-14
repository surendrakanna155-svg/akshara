# Full Regression Report — v19 RC1

**Run ID:** `20260614_104528`  
**Date:** 14 June 2026  
**Command:** `ERP_COVERAGE_MODE=full qa/patrol/run_erp_coverage.sh`  
**Device:** `emulator-5554` (cold boot via existing session)  
**Artifact dir:** `qa/patrol/reports/erp_coverage/20260614_104528/`

---

## Executive summary

| Gate | Result |
|------|--------|
| `flutter analyze` | **0 issues** |
| `flutter test` | **1304 passed** (~1 skipped) |
| Patrol full mode | **25 / 25 suites passed** |
| Flaky suites detected | **0** (no failures; no rerun required) |
| **Overall** | **PASS** |

---

## Metrics

| Metric | Before run | After run |
|--------|----------:|----------:|
| Flutter tests | 1304 | **1304** |
| Patrol full suites | 22 baseline + 3 new (individual) | **25 / 25** unified |
| P0 E2E journey coverage | ~62% | **~62%** (unchanged — no new features) |
| Client QA readiness (mock pilot) | ~95% | **~96%** |
| Module workflow proxy | 100% | **100%** (`coverage_summary.json`) |

---

## Runtime

| Phase | Duration (approx.) |
|-------|-------------------:|
| `flutter analyze` | ~3s |
| `flutter test` | ~55s |
| Module coverage script | ~1s |
| Patrol 25 suites | ~52 min |
| **Total wall time** | **~53 min** |

---

## Patrol suites (25/25)

| # | Suite | Status |
|---|-------|--------|
| 1 | `teacher_workflows_test` | Pass |
| 2 | `parent_workflows_test` | Pass |
| 3 | `student_workflows_test` | Pass |
| 4 | `principal_workflows_test` | Pass |
| 5 | `erp_workflows_test` | Pass |
| 6 | `finance_workflows_test` | Pass |
| 7 | `inventory_workflows_test` | Pass |
| 8 | `sis_workflows_test` | Pass |
| 9 | `admissions_workflows_test` | Pass |
| 10 | `admissions_e2e_journey_test` | Pass |
| 11 | `finance_fee_assignment_e2e_test` | Pass |
| 12 | `finance_fee_collection_e2e_test` | Pass |
| 13 | `finance_full_journey_e2e_test` | Pass |
| 14 | `teacher_attendance_e2e_test` | Pass |
| 15 | `hr_workflows_test` | Pass |
| 16 | `hr_leave_e2e_test` | Pass |
| 17 | `inventory_po_e2e_test` | Pass |
| 18 | `transport_route_e2e_test` | Pass |
| 19 | `transport_workflows_test` | Pass |
| 20 | `library_workflows_test` | Pass |
| 21 | `hostel_workflows_test` | Pass |
| 22 | `alumni_workflows_test` | Pass |
| 23 | `control_center_workflows_test` | Pass |
| 24 | `management_workflows_test` | Pass |
| 25 | `screenshot_validation_test` | Pass |

Per-suite logs: `qa/patrol/reports/erp_coverage/20260614_104528/<suite_name>.log`

---

## E2E business journeys verified

| Journey | Suite |
|---------|-------|
| Admissions → SIS → Finance handoff | `admissions_e2e_journey_test` |
| Finance assign → invoice → collect | `finance_full_journey_e2e_test` |
| Teacher attendance persistence | `teacher_attendance_e2e_test` |
| HR leave submit | `hr_leave_e2e_test` |
| Inventory PO draft | `inventory_po_e2e_test` |
| Transport route draft | `transport_route_e2e_test` |

---

## Flake policy outcome

- **Failures:** 0  
- **Reruns:** not required  
- **Emulator:** stable after cold-boot fix (`scripts/qa/start_emulator.sh`)

---

## Known non-blockers (product scope)

| Item | RC impact |
|------|-----------|
| Exam administration journey | Out of scope (**D**) |
| Live API pilot | Not validated in this run (`ENABLE_API_MODE=false`) |
| HR payroll writes | Not implemented |
| Uncommitted `main` working tree | Process blocker for branch cut — commit before RC |

---

## Infrastructure changes validated

- `scripts/qa/start_emulator.sh` — cold boot  
- `qa/patrol/run_erp_coverage.sh` — auto-start emulator when no device  
- 3 new E2E suites in full target list  

---

## Final verdict: `release/v19-rc1`

### **GO WITH CONDITIONS**

| Condition | Required before RC tag |
|-----------|------------------------|
| Commit gated QA stabilization changes on `main` | Yes |
| Create `release/v19-rc1` from that commit | Yes |
| Bump `pubspec.yaml` to `19.0.0-rc.1+190` | Yes |
| Pilot scope freeze (see `ARCHITECTURE_FREEZE_RECOMMENDATION.md`) | Yes |
| No production SaaS / live API claims without backend sign-off | Yes |
| Run `Flutter Patrol RC` workflow (full) on GitHub after push | Recommended |

**Not NO GO** — all automated gates green.

**Not unconditional GO** — dirty working tree and pilot scope limits remain.

---

## Related documents

- `docs/QA/ci_validation_report.md`
- `docs/ARCHITECTURE_FREEZE_RECOMMENDATION.md`
- `docs/RELEASE_CANDIDATE_PLAN.md`
- `docs/QA/overnight_summary.md`
