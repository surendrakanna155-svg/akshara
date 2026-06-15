# Patrol Expansion Plan (Post M13)

**Generated:** 2026-06-15 20:06 UTC

## Current state

- Patrol workflow **files**: **89**
- Patrol test **cases**: **222**
- Expansion target: **150–300** suites
- Gap to minimum: **61** new suite files

## Tier definitions

| Tier | Scope | Coverage target |
|------|-------|----------------:|
| **1** | Critical business actions (fees, admissions, payroll, approvals) | 100% |
| **2** | Management + AI + Multi-School + Director | 95% |
| **3** | Filters, exports, navigation depth, vertical packs | 90% |

## Backlog (batch-ready)

| Tier | Suite file | Area | Target |
|------|------------|------|--------|
| 1 | `finance_filters_e2e_test.dart` | Finance filters & defaulters | 100% |
| 1 | `finance_exports_e2e_test.dart` | Finance PDF/Excel export | 100% |
| 1 | `admissions_exports_e2e_test.dart` | Admissions pipeline exports | 100% |
| 1 | `management_actions_e2e_test.dart` | Management task & settings actions | 100% |
| 1 | `sis_filters_e2e_test.dart` | SIS registry filters & promote | 100% |
| 2 | `director_portal_navigation_e2e_test.dart` | Director all sub-routes | 95% |
| 2 | `trust_intelligence_tabs_e2e_test.dart` | Trust intelligence all tabs | 95% |
| 2 | `ai_generation_variants_e2e_test.dart` | AI summarize/recommend per module | 95% |
| 2 | `multi_school_navigation_e2e_test.dart` | Multi-school portfolio drill | 95% |
| 2 | `platform_intelligence_drill_e2e_test.dart` | Platform intelligence KPI drill | 95% |
| 2 | `copilot_module_variants_e2e_test.dart` | Copilot per ERP module context | 95% |
| 3 | `industry_pack_navigation_e2e_test.dart` | Industry vertical sub-nav | 90% |
| 3 | `healthcare_navigation_e2e_test.dart` | Healthcare sub-screens | 90% |
| 3 | `hostel_visitors_e2e_test.dart` | Hostel visitors & mess | 90% |
| 3 | `library_digital_resources_e2e_test.dart` | Library digital resources | 90% |
| 3 | `alumni_donations_e2e_test.dart` | Alumni donations & campaigns | 90% |
| 3 | `control_center_billing_e2e_test.dart` | Control center billing actions | 90% |
| 3 | `hr_recruitment_e2e_test.dart` | HR recruitment pipeline | 90% |
| 3 | `transport_telemetry_e2e_test.dart` | Transport telemetry screen | 90% |
| 3 | `inventory_reports_export_e2e_test.dart` | Inventory report PDF export | 90% |

## Batch execution policy

1. Implement **10–20 suites per cycle**
2. Run `flutter analyze` + `flutter test` + affected Patrol
3. Fix failures before next batch
4. Update `docs/QA/FINAL_COVERAGE_REPORT.md` after each batch
5. Register new targets in `qa/patrol/run_erp_coverage.sh`

## Cycle 1 (this release)

See `patrol_test/workflows/*_e2e_test.dart` batch-1 additions and `qa/patrol/run_erp_coverage.sh` updates.
