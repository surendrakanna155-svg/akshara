# Patrol Batch 01 — Certification Report

**Date:** 2026-06-18  
**Branch:** `feature/m15-theme`  
**Suite:** `patrol_test/workflows/patrol_batch1_p0_expansion_e2e_test.dart`  
**Device:** `emulator-5554` (headless)  
**Duration:** 5m 6s  
**Result:** **12/12 PASS**

---

## New journeys (12)

| # | Journey | P0 area |
|---|---------|---------|
| 1 | Finance audit register export button | Finance |
| 2 | Finance reports Excel export button | Finance |
| 3 | Approval center leave filter | Approvals |
| 4 | Approval center attendance filter | Approvals |
| 5 | Approval center finance filter | Approvals |
| 6 | Parent attendance correction dialog | Attendance |
| 7 | Teacher attendance post-submit lock | Attendance |
| 8 | Exam administration create dialog | Exams |
| 9 | SIS registry export button | SIS |
| 10 | Principal command center | Dashboard |
| 11 | Student 360 attendance tab | Student 360 |
| 12 | Management dashboard principal overview | Dashboard |

---

## Updated journeys

| Journey | Change |
|---------|--------|
| `workflow_finance_audit_register.yaml` | Status: stub → Patrol-linked (batch1 test 1) |
| `qa/patrol/run_erp_coverage.sh` | Added batch1 suite to FULL targets |

---

## Defects found

| ID | Severity | Screen | Description |
|----|----------|--------|-------------|
| UX-B01-03 | **High** | Exam create dialog | Section dropdown listed all classes → duplicate `A/B/C/D` values crashed dialog |
| UX-B01-01 | Low | Approval center | Attendance/Finance/Inventory filter chips lacked stable QA keys |
| UX-B01-04 | Medium | Parent attendance | Correction button only in bottom sheet — Patrol needed date-row tap |

---

## Defects fixed

| ID | Fix |
|----|-----|
| UX-B01-03 | `exam_create_dialog.dart` — filter sections by selected grade; reset section on class change |
| UX-B01-01 | Added `QaTestKeys.approvalTypeFilterAttendance/Finance/Inventory` + wired in `ApprovalTypeFilter` |
| UX-B01-04 | Patrol uses `5 Jun` row tap + `parentAttendanceCorrectionButton` key |

---

## Coverage delta

| Metric | Before | After | Δ |
|--------|--------|-------|---|
| Certified Patrol journeys | 90 | **102** | +12 |
| P0 Patrol depth (approvals) | 1 filter | 3 filters | +2 |
| Finance audit register | stub YAML | Patrol green | +1 |
| Parent correction Patrol | teacher only | parent dialog | +1 |
| Exam create UI crash | latent | fixed | — |
| Overall QA coverage % | ~38% | **~42%** | +4% |
| Phase 1 journey count (100 target) | 90 | **102** | **target met** |

---

## Test results

| Gate | Result |
|------|--------|
| `flutter analyze` (changed paths) | **PASS** — 0 errors |
| Affected widget tests | **PASS** — 19 tests |
| Patrol Batch 01 | **PASS** — 12/12 |
| Pilot closure (prior) | **PASS** — 9/9 (2026-06-18) |

---

## Remaining gaps (Batch 02 queue)

1. Exam publish approval full chain (coordinator → principal → publish)
2. Fee structure approval Patrol E2E
3. Parent attendance correction **submit** → approval center
4. Finance concession assign + approve
5. Inventory PO dual-persona (storekeeper vs manager)
6. HR leave approval Patrol depth
7. API-mode Patrol on staging (post-F7)

---

## Artifacts

| Path | Description |
|------|-------------|
| `patrol_test/workflows/patrol_batch1_p0_expansion_e2e_test.dart` | Batch 01 suite |
| `docs/PATROL_QA_ORCHESTRATOR.md` | Updated tracker |
| `docs/PATROL_COVERAGE_AUDIT.md` | Module inventory |
| `docs/UI_UX_AUDIT_BACKLOG.md` | Defect log |

---

**Certified by:** Continuous Patrol QA Program — Batch 01  
**Next:** Batch 02 — approval write paths (15 journeys)
