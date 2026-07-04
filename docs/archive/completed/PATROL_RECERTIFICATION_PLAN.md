# Patrol Re-Certification Plan — 89 Suites

**Branch:** `release/v1.0-preprod`  
**Baseline commit:** `2ed4275` (+ gap-closure fixes)  
**Registry:** `qa/patrol/run_erp_coverage.sh` → `ALL_TARGETS`  
**Date:** 2026-06-16  
**Policy:** Do **not** add new suites until this plan completes.

---

## Summary

| Metric | Value |
|--------|------:|
| Total registered suites | **89** |
| Full regression scope (`ERP_COVERAGE_MODE=full`) | **88** (excludes smoke duplicate) |
| Device-certified post-`2ed4275` | **10** |
| Awaiting re-certification | **78** |
| Device-certified failing | **0** |
| Patrol test cases (all workflow files) | **222** |

---

## Pre-flight gates (every batch)

```bash
flutter analyze          # must be 0 issues
flutter test             # must be all green
bash scripts/qa/start_emulator.sh   # cold boot if adb empty
```

Patrol dart-defines (from `run_erp_coverage.sh`):

```
APP_ENV=development
ENABLE_QA_LOGIN=true
ENABLE_DEMO_AUTH=true
ENABLE_API_MODE=false
```

---

## Certification status legend

| Status | Meaning |
|--------|---------|
| ✅ **Certified** | Green on `emulator-5554` post-`2ed4275` |
| ⏳ **Pending** | Registered but not re-run since expansion |
| 🔁 **Rerun priority** | Failed in last partial full run (`20260615_195149`) or gap-closure fix |

---

## Batch 0 — Smoke (fast gate)

| # | Suite | Status | Dependencies |
|---|-------|--------|--------------|
| 1 | `erp_coverage_smoke_test.dart` | ⏳ | QA login, splash, admin shell |

**Command:** `./qa/patrol/run_erp_coverage.sh` (~2 min)

---

## Batch 1 — Post-expansion (certified)

**Script:** `./qa/patrol/rerun_batch1.sh`  
**Result:** ✅ **10/10** on `Medium_Phone_API_36.0`

| # | Suite | Status |
|---|-------|--------|
| 2 | `finance_filters_e2e_test.dart` | ✅ |
| 3 | `finance_exports_e2e_test.dart` | ✅ |
| 4 | `admissions_exports_e2e_test.dart` | ✅ |
| 5 | `management_actions_e2e_test.dart` | ✅ |
| 6 | `sis_filters_e2e_test.dart` | ✅ |
| 7 | `director_portal_navigation_e2e_test.dart` | ✅ |
| 8 | `industry_pack_navigation_e2e_test.dart` | ✅ |
| 9 | `healthcare_navigation_e2e_test.dart` | ✅ |
| 10 | `hostel_visitors_e2e_test.dart` | ✅ |
| 11 | `library_digital_resources_e2e_test.dart` | ✅ |

---

## Batch 2 — Core persona workflows (12 suites)

**Dependencies:** QA login, RBAC personas, mobile shells  
**Suggested order:** teacher → parent → student → principal → erp

| # | Suite | Status | Notes |
|---|-------|--------|-------|
| 12 | `teacher_workflows_test.dart` | ⏳ | Teacher shell |
| 13 | `parent_workflows_test.dart` | ⏳ | Parent shell |
| 14 | `student_workflows_test.dart` | ⏳ | Student shell |
| 15 | `principal_workflows_test.dart` | ⏳ | Principal routes |
| 16 | `erp_workflows_test.dart` | ⏳ | Admin navigation |
| 17 | `finance_workflows_test.dart` | ⏳ | Finance module |
| 18 | `inventory_workflows_test.dart` | ⏳ | Inventory module |
| 19 | `sis_workflows_test.dart` | ⏳ | SIS module |
| 20 | `admissions_workflows_test.dart` | ⏳ | Admissions |
| 21 | `hr_workflows_test.dart` | ⏳ | HR |
| 22 | `transport_workflows_test.dart` | ⏳ | Transport |
| 23 | `library_workflows_test.dart` | ⏳ | Library |

---

## Batch 3 — Academic & SIS deep journeys (8 suites)

| # | Suite | Status | Fix dependency |
|---|-------|--------|----------------|
| 24 | `sis_academic_operations_e2e_test.dart` | ⏳ | M1 promotion/reshuffle |
| 25 | `continuity_e2e_test.dart` | ⏳ | M2 continuity |
| 26 | `workflow_automation_e2e_test.dart` | ⏳ | M3 engine |
| 27 | `admissions_e2e_journey_test.dart` | ⏳ | AD pipeline |
| 28 | `education_remark_e2e_test.dart` | ⏳ | Academic |
| 29 | `sis_profile_edit_e2e_test.dart` | ⏳ | P1-11 |
| 30 | `substitute_teacher_e2e_test.dart` | 🔁 | Stabilized `2ed4275` |
| 31 | `teacher_reassignment_e2e_test.dart` | ⏳ | M7 |

---

## Batch 4 — Finance journeys (10 suites)

| # | Suite | Status | Fix dependency |
|---|-------|--------|----------------|
| 32 | `finance_fee_assignment_e2e_test.dart` | ⏳ | Fee structure |
| 33 | `finance_fee_collection_e2e_test.dart` | ⏳ | Collection |
| 34 | `finance_full_journey_e2e_test.dart` | ⏳ | End-to-end |
| 35 | `finance_invoice_e2e_test.dart` | ⏳ | Invoice |
| 36 | `finance_offline_payment_e2e_test.dart` | ⏳ | FV-16 |
| 37 | `finance_qr_payment_e2e_test.dart` | 🔁 | QR stabilized `2ed4275` |
| 38 | `parent_receipt_pdf_e2e_test.dart` | 🔁 | PDF stabilized `2ed4275` |
| 39 | `admissions_settings_persistence_e2e_test.dart` | ⏳ | P1-05 |
| 40 | `book_distribution_e2e_test.dart` | ⏳ | FV-11 |
| 41 | `growth_campaign_e2e_test.dart` | ⏳ | FV-18 |

---

## Batch 5 — HR & management (9 suites)

| # | Suite | Status |
|---|-------|--------|
| 42 | `hr_leave_e2e_test.dart` | ⏳ |
| 43 | `hr_payroll_e2e_test.dart` | ⏳ |
| 44 | `hr_employee_crud_e2e_test.dart` | ⏳ |
| 45 | `hr_leave_approval_e2e_test.dart` | ⏳ |
| 46 | `management_approval_e2e_test.dart` | ⏳ |
| 47 | `management_dashboard_export_e2e_test.dart` | ⏳ |
| 48 | `management_insight_routes_e2e_test.dart` | ⏳ |
| 49 | `management_kpi_drill_e2e_test.dart` | ⏳ |
| 50 | `management_workflows_test.dart` | ⏳ |

---

## Batch 6 — Operations modules (10 suites)

| # | Suite | Status | Fix dependency |
|---|-------|--------|----------------|
| 51 | `inventory_po_e2e_test.dart` | 🔁 | PO handoff gap closed |
| 52 | `inventory_lifecycle_e2e_test.dart` | ⏳ | Asset lifecycle |
| 53 | `inventory_replacement_e2e_test.dart` | ⏳ | FV-12 |
| 54 | `library_issue_return_e2e_test.dart` | ⏳ | Library |
| 55 | `hostel_allocation_e2e_test.dart` | ⏳ | Hostel |
| 56 | `hostel_workflows_test.dart` | ⏳ | Hostel |
| 57 | `transport_route_e2e_test.dart` | ⏳ | Transport |
| 58 | `transport_activate_e2e_test.dart` | ⏳ | Transport |
| 59 | `transport_allocation_e2e_test.dart` | ⏳ | Transport |
| 60 | `alumni_workflows_test.dart` | ⏳ | Alumni |

---

## Batch 7 — Intelligence, copilot, AI (8 suites)

| # | Suite | Status |
|---|-------|--------|
| 61 | `platform_intelligence_e2e_test.dart` | ⏳ |
| 62 | `operations_hub_e2e_test.dart` | ⏳ |
| 63 | `resource_optimization_e2e_test.dart` | ⏳ |
| 64 | `ai_content_generation_e2e_test.dart` | ⏳ |
| 65 | `universal_ai_assistant_e2e_test.dart` | ⏳ |
| 66 | `parent_meeting_summary_e2e_test.dart` | ⏳ |
| 67 | `copilot_context_e2e_test.dart` | ⏳ |
| 68 | `copilot_dock_e2e_test.dart` | ⏳ |
| 69 | `ai_access_settings_e2e_test.dart` | ⏳ |

---

## Batch 8 — Multi-school & director (5 suites)

| # | Suite | Status | Fix dependency |
|---|-------|--------|----------------|
| 70 | `multi_school_operations_e2e_test.dart` | ⏳ | M9 |
| 71 | `director_portal_e2e_test.dart` | 🔁 | Reports stabilized |
| 72 | `trust_intelligence_e2e_test.dart` | 🔁 | Nav stabilized `2ed4275` |
| 73 | `branch_operations_e2e_test.dart` | ⏳ | M9 |
| 74 | `franchise_portfolio_e2e_test.dart` | ⏳ | M9 |
| 75 | `control_center_workflows_test.dart` | ⏳ | CC |

---

## Batch 9 — Platform evolution M10–M12 (4 suites)

| # | Suite | Status |
|---|-------|--------|
| 76 | `organization_builder_e2e_test.dart` | ⏳ |
| 77 | `dynamic_widget_platform_e2e_test.dart` | ⏳ |
| 78 | `platform_operations_e2e_test.dart` | ⏳ |
| 79 | `communication_broadcast_e2e_test.dart` | ⏳ |

---

## Batch 10 — Multi-industry M13 (7 suites)

| # | Suite | Status |
|---|-------|--------|
| 80 | `industry_framework_e2e_test.dart` | ⏳ |
| 81 | `healthcare_vertical_e2e_test.dart` | ⏳ |
| 82 | `salon_vertical_e2e_test.dart` | ⏳ |
| 83 | `restaurant_vertical_e2e_test.dart` | ⏳ |
| 84 | `accommodation_vertical_e2e_test.dart` | ⏳ |
| 85 | `white_label_platform_e2e_test.dart` | ⏳ |
| 86 | `school_memories_admin_e2e_test.dart` | ⏳ |

---

## Batch 11 — Misc & validation (3 suites)

| # | Suite | Status |
|---|-------|--------|
| 87 | `teacher_attendance_e2e_test.dart` | ⏳ |
| 88 | `timetable_optimization_apply_e2e_test.dart` | ⏳ |
| 89 | `screenshot_validation_test.dart` | ⏳ |

---

## Recommended execution order

```
Phase A — Gates
  flutter analyze → flutter test

Phase B — Smoke
  ./qa/patrol/run_erp_coverage.sh

Phase C — Already certified (confirm no regression)
  ./qa/patrol/rerun_batch1.sh

Phase D — Priority reruns (gap-closure fixes)
  inventory_po_e2e_test
  finance_qr_payment_e2e_test
  parent_receipt_pdf_e2e_test
  director_portal_e2e_test
  trust_intelligence_e2e_test
  substitute_teacher_e2e_test

Phase E — Full regression (88 suites)
  ERP_COVERAGE_MODE=full ./qa/patrol/run_erp_coverage.sh
```

**Estimated duration:** ~60–90 min full run; split into batches if INFRA-03 (long session) triggers.

---

## Infrastructure mitigations

| ID | Mitigation |
|----|------------|
| INFRA-01 | `bash scripts/qa/start_emulator.sh` before Patrol |
| INFRA-02 | No `/` in patrolTest descriptions; avoid `flutter clean` mid-session |
| INFRA-03 | Split runs by batch; cold boot between batches |
| INFRA-04 | Local Android emulator for certification (not CI macOS) |
| INFRA-05 | Capture run ID locally — `qa/patrol/reports/` is gitignored |

---

## Auth / QA dependencies

All suites assume:

- `ENABLE_QA_LOGIN=true` — instant persona login
- `ENABLE_DEMO_AUTH=true` — mock repositories
- `ENABLE_API_MODE=false` — no live API

Logout flows now return to `/qa-login` (PATROL-002 resolved).

---

## Success criteria

| Criterion | Target |
|-----------|--------|
| Suites passing | **88/88** (full mode) or **89/89** (incl. smoke) |
| Device-certified failing | **0** |
| Product gaps blocking Patrol | **0** |
| `flutter analyze` | 0 issues |
| `flutter test` | All green |

Upon success, update `docs/PATROL_CURRENT_STATUS.md` and proceed to Patrol expansion planning (`docs/QA/PATROL_EXPANSION_PLAN.md`).

---

## Related docs

- `docs/FINAL_GAP_INVENTORY.md` — gap classification
- `docs/FINAL_PRE_PATROL_STATUS.md` — readiness assessment
- `docs/PATROL_CURRENT_STATUS.md` — live status board
- `qa/patrol/reports/bugs.json` — resolved bug tracker
