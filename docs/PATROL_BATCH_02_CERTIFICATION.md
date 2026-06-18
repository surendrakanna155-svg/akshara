# Patrol Batch 02 — Certification Report

**Date:** 2026-06-18  
**Branch:** `feature/m15-theme`  
**Suite:** `patrol_test/workflows/patrol_batch2_approval_write_e2e_test.dart`  
**Device:** `emulator-5554` (headless)  
**Duration:** 7m 51s  
**Result:** **14/14 PASS**

---

## New journeys (14)

| # | Journey | P0 area |
|---|---------|---------|
| 1 | Exam submit for principal approval | Exams / Approvals |
| 2 | Principal approves seeded exam results | Approvals |
| 3 | Fee structure create submits for approval | Finance |
| 4 | Finance concession assign submits for approval | Finance |
| 5 | Parent attendance correction submit | Attendance |
| 6 | Principal attendance correction inbox filter | Approvals |
| 7 | Inventory PO draft create | Inventory |
| 8 | HR leave submit for approval | HR |
| 9 | Exam marks entry saves final open slot | Exams |
| 10 | Finance fee structure create dialog | Finance |
| 11 | Finance concession assign dialog | Finance |
| 12 | Management attendance corrections admin list | Attendance |
| 13 | Teacher attendance post-submit lock | Attendance |
| 14 | Principal approval center inventory filter | Approvals |

---

## Updated journeys

| Journey | Change |
|---------|--------|
| `workflow_finance_concession_approval.yaml` | Status: stub → Patrol-linked (batch2 tests 4, 11) |
| `workflow_teacher_attendance_correction.yaml` | Patrol batch2 test 13 validates post-submit lock |
| `qa/patrol/run_erp_coverage.sh` | Batch 02 suite wired in FULL targets |

---

## Defects found

| ID | Severity | Screen | Description |
|----|----------|--------|-------------|
| UX-B02-01 | **High** | Parent attendance | Correction snackbar lost after bottom-sheet dismiss — sheet context unmounted |
| UX-B02-02 | **Medium** | Finance discounts | `Assign concession` off-screen on mobile; Patrol scroll/tap unreliable |
| UX-B02-03 | Low | Finance discounts | Nested scrollables caused `scrollUntilVisible` "Too many elements" in Patrol |

---

## Defects fixed

| ID | Fix |
|----|-----|
| UX-B02-01 | `parent_attendance_screen.dart` — capture host `ScaffoldMessenger` + defer dialog via `addPostFrameCallback` |
| UX-B02-02 | `finance_discounts_screen.dart` — stack assign button below header on mobile |
| UX-B02-03 | Patrol helper uses `scrollModuleBody` + Patrol `$(key).scrollTo().tap()` |
| UX-B02-04 | Added `parentAttendanceCorrectionSuccessSnackbar` + `financeAssignConcessionSuccessSnackbar` QA keys |

---

## Coverage delta

| Metric | Before | After | Δ |
|--------|--------|-------|---|
| Certified Patrol journeys | 102 | **116** | +14 |
| Approval write-path depth | submit-only partial | 8 submit + 4 inbox/dialog | +12 depth |
| Parent correction submit | dialog only (B01) | full submit green | +1 |
| Finance concession assign | stub YAML | Patrol green | +1 |
| Overall QA coverage % | ~42% | **~46%** | +4% |

---

## Test results

| Gate | Result |
|------|--------|
| `flutter analyze` (changed paths) | **PASS** — 0 errors |
| Affected unit tests | **PASS** — parent correction + finance write |
| Patrol Batch 02 | **PASS** — 14/14 |
| Patrol Batch 01 (regression) | Not re-run this batch (prior 12/12) |

---

## Deferred to Batch 02b (cross-persona chains)

1. Finance create → principal approve concession (requires reliable persona switch)
2. Parent submit → principal approve attendance correction
3. Inventory PO → principal approve
4. Exam publish → parent sees results

---

## Artifacts

| Path | Description |
|------|-------------|
| `patrol_test/workflows/patrol_batch2_approval_write_e2e_test.dart` | Batch 02 suite |
| `patrol_test/helpers/approval_center_journey_helpers.dart` | Principal inbox helpers |
| `docs/PATROL_QA_ORCHESTRATOR.md` | Updated tracker |
| `docs/UI_UX_AUDIT_BACKLOG.md` | Defect log |

---

**Certified by:** Continuous Patrol QA Program — Batch 02  
**Next:** Batch 02b — cross-persona approval chains; Batch 03 — director portal + tablet breakpoints
