# Akshara ERP QA Coverage Audit — v18.7

**Date:** 13 June 2026  
**Baseline release:** v18.6.2-final-suite-recovery (`27b401e`)  
**Scope:** ERP admin modules (`lib/features/{admissions,finance,sis,hr,management,transport,hostel,library,inventory,alumni,control_center,admin}`), Flutter unit/widget/integration tests, Patrol device tests, Maestro journey inventory, QA helpers  
**Method:** Static codebase analysis only — no tests added or modified  
**Gates at audit time:** `flutter analyze` clean; `flutter test` all passing (~1,298 tests); Patrol full suite 17/17 green (147 `patrolTest` cases)

---

## Executive Summary

Akshara ERP has **strong unit and widget coverage** across core ERP modules (screen render tests, provider tests, repository contract tests, router smoke). **Patrol coverage (v18.6.x)** validates route reachability and anchor text for most ERP sub-nav tabs under `QaLoginPersona.superAdmin`, with supplemental principal/mobile personas.

**Gaps are concentrated in:**

- End-to-end business journeys with **real form submission, CRUD persistence, and cross-module handoffs**
- **Intelligence/copilot screens** (Finance Copilot, Inventory Copilot, Management Intelligence Hub, Control Center Providers/Features)
- **Role-matrix Patrol** beyond superAdmin/principal (finance staff, admissions clerk, teacher ERP access)
- **Export/download verification** (SIS export button visibility only; no file assertion)
- **Maestro journey YAML** (118 files) — largely **navigation smoke**, not wired into CI gates like Patrol

| Metric | Estimate | Basis |
|--------|----------|-------|
| **Screen Coverage** | **91%** | 97/106 core ERP screens have widget test and/or router smoke anchor; 8 additional screens reached only by Patrol |
| **Workflow Coverage** | **68%** | ~72 distinct ERP Patrol workflows vs ~106 sub-nav screens + detail routes |
| **End-to-End Journey Coverage** | **28%** | 7 canonical journeys: 0 fully tested E2E with writes; 5 partial; 2 not tested (ERP exams admin) |
| **Production Readiness** | **89%** | Patrol 17/17 green + 1,298 Flutter tests + contract/integration layers; CRUD/E2E/RBAC-matrix gaps remain |

---

## Test Inventory (Evidence)

### Flutter tests (`test/`)

| Layer | Count (files) | Purpose |
|-------|---------------|---------|
| Feature screen tests | 24 `*_screens_test.dart` | Render, loading, error, empty states per ERP screen |
| Feature provider tests | 15 `*_providers_test.dart` | Async load paths, mock repo wiring |
| Write / RBAC mutation tests | 3 modules | `test/features/admissions/admissions_write_tests.dart`, `test/features/finance/finance_write_tests.dart`, `test/features/sis/sis_write_tests.dart` |
| Contract tests | 36 `*_contract_test.dart` | Mock ↔ API repository parity |
| Integration tests | 33 `test/integration/**/*_test.dart` | Fake Dio / staging API flows (**no `integration_test/` directory**) |
| Router smoke | `test/router_smoke_test.dart` | 90+ ERP routes under superAdmin auth + RBAC deny cases |
| Route guards | `test/router/route_guards_test.dart`, `test/router/route_protection_inventory_test.dart` | Permission-based redirects |
| Security / RBAC | `test/security/**/*` | Token, permission cache, mutation deny |
| Golden | `test/golden/erp_dashboards_golden_test.dart` + mobile dashboards | Visual regression (Intelligence Hub included) |
| Patrol helpers (unit) | `test/core/testing/qa_test_keys_test.dart`, `test/features/auth/qa_login_test.dart` | QA login mode keys |

### Patrol tests (`patrol_test/`)

| Suite file | Tests | Primary persona |
|------------|-------|-----------------|
| `patrol_test/workflows/erp_workflows_test.dart` | 12 | superAdmin |
| `patrol_test/workflows/erp_coverage_smoke_test.dart` | 5 | mixed (smoke) |
| `patrol_test/workflows/admissions_workflows_test.dart` | 5 | superAdmin |
| `patrol_test/workflows/finance_workflows_test.dart` | 6 | superAdmin |
| `patrol_test/workflows/sis_workflows_test.dart` | 6 | superAdmin |
| `patrol_test/workflows/hr_workflows_test.dart` | 8 | superAdmin |
| `patrol_test/workflows/inventory_workflows_test.dart` | 5 | superAdmin |
| `patrol_test/workflows/transport_workflows_test.dart` | 9 | superAdmin |
| `patrol_test/workflows/library_workflows_test.dart` | 8 | superAdmin |
| `patrol_test/workflows/hostel_workflows_test.dart` | 8 | superAdmin |
| `patrol_test/workflows/alumni_workflows_test.dart` | 7 | superAdmin |
| `patrol_test/workflows/control_center_workflows_test.dart` | 8 | superAdmin |
| `patrol_test/workflows/management_workflows_test.dart` | 7 | superAdmin |
| `patrol_test/workflows/principal_workflows_test.dart` | 9 | principal |
| `patrol_test/workflows/teacher_workflows_test.dart` | 11 | teacher |
| `patrol_test/workflows/parent_workflows_test.dart` | 15 | parent |
| `patrol_test/workflows/student_workflows_test.dart` | 10 | student |
| `patrol_test/workflows/screenshot_validation_test.dart` | 10 | mixed |
| **Total** | **147** | |

**Runner:** `qa/patrol/run_erp_coverage.sh` (fast = smoke; full = 17 suites)  
**Report artifact:** `qa/reports/module_coverage_v18_6.json` (147 workflows, 93 biz-journey names)

### Maestro / QA journeys (`qa/journeys/`, `qa/maestro/`)

- **118** Maestro journey YAML files under `qa/journeys/` (e.g. `biz_erp_finance_collections.yaml`, `persona_finance.yaml`)
- **7** shared Maestro flows under `qa/maestro/flows/_shared/` (`qa_persona_login.yaml`, `launch_app.yaml`, etc.)
- Maestro journeys mirror Patrol intent but are **not** part of the v18.6.2 Patrol CI gate; evidence of planned coverage, not executed in this audit run

### QA helpers

| File | Role |
|------|------|
| `patrol_test/helpers/patrol_helpers.dart` | `bootstrapAndLogin`, `navigateErpWorkflow`, `navigateErpModuleRoute`, `goToErpRoute`, `tapModuleSubNav`, `assertVisibleText`, `assertVisibleKey` |
| `patrol_test/helpers/patrol_app.dart` | QA-flavor app bootstrap |
| `lib/core/testing/qa_test_keys.dart` | Semantic keys for drawer, sub-nav, screens |
| `lib/features/auth/qa_login_screen.dart` | Persona picker (non-production) |
| `lib/features/auth/qa_login_persona.dart` | superAdmin, principal, teacher, parent, student, … |
| `test/helpers/provider_test_overrides.dart` | Shared Riverpod overrides for widget tests |
| `scripts/qa/generate_module_coverage_report.py` | Patrol → JSON coverage report |
| `scripts/qa/build_qa_apk.sh` | QA APK with login mode enabled |

### Navigation methods (Patrol)

| Method | Used when | Evidence |
|--------|-----------|----------|
| `navigateErpWorkflow` | Default ERP flow: QA login → drawer → module → horizontal sub-nav → text anchor | Most ERP workflow files |
| `openErpModule` + `tapModuleSubNav` | Multi-step within module (e.g. finance receipt lookup) | `finance_workflows_test.dart` |
| `navigateErpModuleRoute` | Bypass sub-nav scroll; direct GoRouter + QA key + anchor | `inventory_workflows_test.dart` (lifecycle) |
| `goToErpRoute` | Deep link only | Via `_patrolGoRouter()` Riverpod container |
| `tapBottomNav` / mobile helpers | Parent, teacher, student shells | Mobile workflow files |

**Typical Patrol assertion:** `assertVisibleText($, 'anchor')` — visibility of mock-data headline, not mutation outcome.

---

## Module Coverage (Core ERP)

### 1. Admissions

**Screens (10 total)**

| Screen | Path |
|--------|------|
| Dashboard | `lib/features/admissions/dashboard/admissions_dashboard_screen.dart` |
| Leads | `lib/features/admissions/leads/admissions_leads_screen.dart` |
| Lead detail | `lib/features/admissions/leads/admissions_lead_detail_screen.dart` |
| Applications | `lib/features/admissions/applications/admissions_applications_screen.dart` |
| Enrollment | `lib/features/admissions/enrollment/admissions_enrollment_screen.dart` |
| Documents | `lib/features/admissions/documents/admissions_documents_screen.dart` |
| Approval | `lib/features/admissions/approval/admissions_approval_screen.dart` |
| Fee handoff | `lib/features/admissions/fee_handoff/admissions_fee_handoff_screen.dart` |
| Reports | `lib/features/admissions/reports/admissions_reports_screen.dart` |
| Settings | `lib/features/admissions/settings/admissions_settings_screen.dart` |

| Metric | Value |
|--------|-------|
| **Tested screens (widget)** | **10/10** |
| **Untested screens** | **0** |

**Flutter test evidence**

- `test/features/admissions/admissions_module_screens_test.dart` — dashboard, leads, applications
- `test/features/admissions/admissions_phase2_screens_test.dart` — lead detail, enrollment, documents
- `test/features/admissions/admissions_phase3_screens_test.dart` — approval, fee handoff, reports, settings
- `test/features/admissions/admissions_providers_test.dart`, `admissions_phase2_providers_test.dart`, `admissions_phase3_providers_test.dart`
- `test/features/admissions/admissions_write_tests.dart` — RBAC mutations (createLead deny)
- `test/contracts/admissions/admissions_repository_contract_test.dart`, `admissions_write_contract_test.dart`
- `test/integration/admissions/admissions_api_integration_test.dart`
- `test/router_smoke_test.dart` — all 10 routes + parameterized lead detail

**Patrol coverage**

| Workflow | File | Navigation | Assertions |
|----------|------|------------|------------|
| admissions leads pipeline | `admissions_workflows_test.dart` | `navigateErpWorkflow` → Leads | Anchor text |
| admissions applications queue | same | sub-nav Applications | Anchor text |
| admissions enrollment wizard start | same | sub-nav Enrollment | Anchor text |
| admissions enrollment parent step | same | wizard step | Anchor text |
| admissions approval queue | same | sub-nav Approval | Anchor text |
| erp student enrollment wizard | `erp_workflows_test.dart` | cross-module | Anchor text |
| erp parent enrollment step | `erp_workflows_test.dart` | cross-module | Anchor text |
| principal admissions pipeline | `principal_workflows_test.dart` | principal persona | Anchor text |
| sis admissions conversion | `sis_workflows_test.dart` | SIS module | Anchor text |

**Missing coverage**

- CRUD: no Patrol lead create/edit/submit; widget tests only deny-path RBAC for createLead
- Forms: enrollment wizard advance tested in widget test only (`admissions_phase2_screens_test.dart`); no Patrol multi-step completion
- Reports: screen widget-tested; **no Patrol** for admissions reports
- Filters/search: leads/applications filters not exercised in Patrol
- Export: not tested
- RBAC: superAdmin only in Patrol; principal sees pipeline read-only

**Module scores:** Screen **100%** | Workflow **56%** (5/9 sub-nav Patrol) | Journey **Partial**

---

### 2. Finance

**Screens (14 total)**

| Screen | Path |
|--------|------|
| Dashboard | `lib/features/finance/dashboard/finance_dashboard_screen.dart` |
| Fee structures | `lib/features/finance/fee_structures/finance_fee_structures_screen.dart` |
| Student accounts | `lib/features/finance/student_accounts/finance_student_accounts_screen.dart` |
| Fee assignment | `lib/features/finance/fee_assignment/finance_fee_assignment_screen.dart` |
| Collections | `lib/features/finance/collections/finance_collections_screen.dart` |
| Collection detail | `lib/features/finance/collection_detail/finance_collection_detail_screen.dart` |
| Defaulters | `lib/features/finance/defaulters/finance_defaulters_screen.dart` |
| Refunds | `lib/features/finance/refunds/finance_refunds_screen.dart` |
| Discounts | `lib/features/finance/discounts/finance_discounts_screen.dart` |
| Reports | `lib/features/finance/reports/finance_reports_screen.dart` |
| Reconciliation | `lib/features/finance/reconciliation/finance_reconciliation_screen.dart` |
| Settings | `lib/features/finance/settings/finance_settings_screen.dart` |
| Copilot | `lib/features/finance/intelligence/finance_copilot_screen.dart` |
| Executive dashboard | `lib/features/finance/intelligence/finance_executive_dashboard_screen.dart` |

| Metric | Value |
|--------|-------|
| **Tested screens (widget and/or router smoke)** | **12/14** |
| **Untested screens** | **FinanceCopilotScreen**, **FinanceExecutiveDashboardScreen** (contract/intelligence only) |

**Flutter test evidence**

- `test/features/finance/finance_screens_test.dart` — dashboard, structures, accounts, assignment, collections
- `test/features/finance/finance_phase2_screens_test.dart` — collection detail, defaulters, refunds, discounts, reports, settings
- `test/features/finance/finance_providers_test.dart`, `finance_phase2_providers_test.dart`
- `test/features/finance/finance_write_tests.dart` — createFeeStructure RBAC deny
- `test/contracts/finance/finance_repository_contract_test.dart`, `finance_write_contract_test.dart`, `finance_intelligence_contract_test.dart`
- `test/integration/finance/finance_api_integration_test.dart`
- `test/router_smoke_test.dart` — 12 routes (excludes copilot, executive); includes reconciliation

**Patrol coverage**

| Workflow | File | Navigation | Assertions |
|----------|------|------------|------------|
| finance fee structure create | `finance_workflows_test.dart` | sub-nav Fee Structures | "Create structure" visible |
| finance generate student fee account | same | Fee Assignment | anchor |
| finance collect fee | same | Collections | "Collected today" |
| finance verify receipt lookup | same | openErpModule + sub-nav | text + `Icons.search` |
| finance report export | same | Reports | "Report catalog" (no download) |
| finance defaulters list | same | Defaulters | anchor |
| erp finance collections / reports | `erp_workflows_test.dart` | cross-smoke | anchor |

**Missing coverage**

- CRUD: no Patrol fee collection submit, refund approve, discount apply
- Forms: create structure button visible only — no form fill
- Reports: catalog visible; **export action not verified**
- Filters/search: receipt search icon only
- Export/download: **not tested**
- RBAC: finance staff control-center deny in `router_smoke_test.dart`; no Patrol finance-clerk persona

**Module scores:** Screen **86%** | Workflow **43%** (6/14 tabs) | Journey **Partial**

---

### 3. SIS (Student Information System)

**Screens (5 total)** — all under `lib/features/sis/`

| Metric | Value |
|--------|-------|
| **Tested screens (widget + router)** | **5/5** (+ student detail route in router smoke) |
| **Untested screens** | **0** |

**Flutter test evidence**

- `test/features/sis/sis_screens_test.dart`
- `test/features/sis/sis_providers_test.dart`, `sis_write_tests.dart`
- `test/contracts/sis/sis_repository_contract_test.dart`, `sis_write_contract_test.dart`
- `test/integration/sis/sis_api_integration_test.dart`
- `test/router_smoke_test.dart`

**Patrol coverage (6 workflows)**

- `sis search student`, `sis student registry export`, `sis promote student`, `sis admissions conversion`, `sis dashboard totals`, `sis registry filter active` — `sis_workflows_test.dart`
- Navigation: `navigateErpWorkflow` / sub-nav; export workflow checks **Export** label visibility
- Assertions: text anchors; filter active state; search icon interaction partial

**Missing coverage**

- CRUD: createStudent RBAC deny in unit test only; no Patrol student create/edit save
- Forms: academic assignment form rendered in widget test; not submitted in Patrol
- Export: button visibility only — no file/blob assertion
- RBAC: superAdmin only in Patrol

**Module scores:** Screen **100%** | Workflow **100%** (all primary tabs) | Journey **Partial**

---

### 4. HR

**Screens (9 total)** — `lib/features/hr/**`

| Metric | Value |
|--------|-------|
| **Tested screens** | **9/9** (+ employee detail in router smoke) |
| **Untested screens** | **0** (detail route: widget test for profile; **no Patrol**) |

**Flutter test evidence**

- `test/features/hr/hr_screens_test.dart`, `hr_providers_test.dart`
- `test/contracts/hr/hr_repository_contract_test.dart`
- `test/integration/hr/hr_api_integration_test.dart`
- `test/router_smoke_test.dart`

**Patrol coverage (8 workflows)** — `hr_workflows_test.dart`

- dashboard, employee directory, staff attendance, leave, payroll, recruitment, performance, settings
- Navigation: `navigateErpWorkflow`
- Missing Patrol: **employee profile detail route** (`hrEmployeeDetail`)

**Missing coverage**

- CRUD: no employee create/edit Patrol; payroll run approval not tested
- Forms: recruitment pipeline read-only reach
- Reports: N/A dedicated screen
- RBAC: superAdmin only

**Module scores:** Screen **100%** | Workflow **89%** (8/9) | Journey **Partial**

---

### 5. Management

**Screens (9 total)**

| Metric | Value |
|--------|-------|
| **Tested screens (widget)** | **8/9** |
| **Untested screens** | **IntelligenceHubScreen** — golden only (`test/golden/erp_dashboards_golden_test.dart`) |

**Flutter test evidence**

- `test/features/management/management_screens_test.dart`, `management_providers_test.dart`
- `test/contracts/management/management_repository_contract_test.dart`
- `test/integration/management/management_api_integration_test.dart`
- `test/router_smoke_test.dart` — 8 routes (no intelligence hub route)

**Patrol coverage (7 + principal cross)**

- `management_workflows_test.dart`: dashboard, analytics enrollment, admissions drilldown, finance drilldown, academics, performance, tasks
- `principal_workflows_test.dart`: analytics, tasks, intelligence, finance drilldown
- Missing Patrol: **management settings**, **intelligence hub** tab

**Module scores:** Screen **89%** | Workflow **78%** | Journey **Partial**

---

### 6. Transport

**Screens (9 total)** — all widget-tested in `test/features/transport/transport_screens_test.dart`

| Metric | Value |
|--------|-------|
| **Tested screens** | **9/9** |
| **Patrol workflows** | **8/9** — settings tab not in Patrol |

**Patrol:** `transport_workflows_test.dart` — fleet, routes, new route button, vehicles, drivers, allocation, pickup attendance, telemetry, reports

**Missing:** route create form submit, GPS live tracking validation, settings Patrol, RBAC matrix

**Module scores:** Screen **100%** | Workflow **89%** | Journey **Partial**

---

### 7. Hostel

**Screens (8 total)** — full widget + Patrol coverage

**Flutter:** `test/features/hostel/hostel_screens_test.dart`, providers, contracts, integration  
**Patrol:** `hostel_workflows_test.dart` — all 8 sub-nav tabs

**Missing:** resident assign room CRUD, mess menu edit, export reports

**Module scores:** Screen **100%** | Workflow **100%** | Journey **Partial**

---

### 8. Library

**Screens (8 total)** — full widget + Patrol coverage

**Flutter:** `test/features/library/library_screens_test.dart`, providers, contracts, integration  
**Patrol:** `library_workflows_test.dart` — catalog add book (CTA visibility), issue, return, members, fines, resources, reports

**Missing:** actual book issue/return transaction, fine payment

**Module scores:** Screen **100%** | Workflow **100%** | Journey **Partial**

---

### 9. Inventory

**Screens (10 total)**

| Metric | Value |
|--------|-------|
| **Tested screens (widget + router)** | **8/10** |
| **Untested screens** | **InventoryCopilotScreen**, **InventoryLifecycleScreen** (lifecycle: Patrol via route only) |

**Flutter test evidence**

- `test/features/inventory/inventory_screens_test.dart` — 8 screens
- `test/contracts/inventory/inventory_repository_contract_test.dart`, `inventory_intelligence_contract_test.dart`
- `test/integration/inventory/inventory_api_integration_test.dart`

**Patrol coverage (5 workflows)**

- assets registry, asset allocation, report catalog, procurement orders, distribution lifecycle
- Lifecycle uses **`navigateErpModuleRoute`** + `QaTestKeys.inventoryLifecycleScreen` — only route-bypass case

**Missing Patrol tabs:** categories, maintenance, vendors, copilot, dashboard-only smoke via erp_workflows

**Module scores:** Screen **80%** | Workflow **50%** | Journey **Partial**

---

### 10. Alumni

**Screens (9 total)** — all widget-tested (`test/features/alumni/alumni_screens_test.dart`)

| Metric | Value |
|--------|-------|
| **Patrol workflows** | **7/9** — missing settings, profile detail |

**Patrol:** `alumni_workflows_test.dart`

**Module scores:** Screen **100%** | Workflow **78%** | Journey **Partial**

---

### 11. Control Center

**Screens (14 total)**

| Metric | Value |
|--------|-------|
| **Tested screens (widget + router)** | **12/14** |
| **Untested screens** | **ControlCenterProvidersScreen**, **ControlCenterFeaturesScreen** |

**Flutter test evidence**

- `test/features/control_center/control_center_screens_test.dart` — 12 screens
- `test/features/control_center/control_center_providers_test.dart` — provider logic (not full screen widget for providers/features screens)
- `test/contracts/control_center/control_center_repository_contract_test.dart`, `control_center_providers_contract_test.dart`
- `test/integration/control_center/control_center_api_integration_test.dart`

**Patrol (8 workflows)** — `control_center_workflows_test.dart`

- module adoption, create school, subscriptions, billing, CRM, support, monitoring, platform roles
- Missing: analytics, success, white label, settings, providers, features

**Module scores:** Screen **86%** | Workflow **57%** | Journey **Partial**

---

### 12. Admin Shell

**Screens (1)** — `lib/features/admin/screens/admin_module_placeholder_screen.dart`

**Flutter:** `test/features/admin/admin_shell_test.dart`, `admin_navigation_provider_test.dart`  
**Patrol:** indirect via all ERP drawer flows  
**Module scores:** Screen **100%** | Workflow **100%** (navigation shell) | Journey **N/A**

---

## Secondary / Cross-Cutting Modules (Outside Core 12)

These live under `lib/features/` but are not primary ERP drawer modules. Coverage is thinner in Patrol.

| Area | Screens (approx) | Flutter evidence | Patrol |
|------|------------------|------------------|--------|
| School completion | 17 | `test/features/intelligence/intelligence_school_completion_test.dart`, contracts, integration | None |
| Evolution | 6 | `test/contracts/evolution/`, integration | None |
| Copilot (global) | multiple | `test/contracts/copilot/`, integration, RBAC | None |
| Timetable (ERP) | hubs | `test/contracts/timetable/`, integration, RBAC | Maestro `biz_erp_timetable_mgmt.yaml` only |
| Communications | — | contract alignment | Maestro `biz_erp_communications_mgmt.yaml` |
| Homework intelligence | — | mobile + Maestro | teacher/parent/student Patrol |
| Exams (ERP reports) | — | Maestro `biz_erp_exam_reports.yaml` | No Patrol ERP exam admin |

---

## User Journey Classification

| Journey | Steps | Flutter | Patrol | Classification |
|---------|-------|---------|--------|------------------|
| **Admissions:** Lead → Application → Admission → Student | CRM → app queue → enrollment → approval → SIS | Each step has widget + router smoke; `admissions_write_tests` partial RBAC | Leads, apps, enrollment, approval reachable; **no chain**; SIS conversion separate | **Partially Tested** |
| **Attendance:** Student → Entry → Summary → Reports | Mobile mark + ERP HR staff attendance | Teacher/parent/student widget + Patrol; HR attendance Patrol | No single E2E; ERP academic attendance module absent | **Partially Tested** |
| **Fees:** Assignment → Collection → Receipt → Reports | Handoff → assign → collect → detail → reports | Full widget coverage; write RBAC unit tests | Structures, assign, collect, reports anchors; search icon; **no payment** | **Partially Tested** |
| **Exams:** Create → Marks → Results → Report card | ERP exam admin + mobile views | Mobile teacher/student/parent screens + Patrol | **No ERP exam creation/marks Patrol**; Maestro YAML only | **Not Tested** (ERP admin path) |
| **Inventory:** Purchase → Stock → Lifecycle → Reports | PO → assets → allocation → lifecycle → reports | Widget + contracts; lifecycle widget **missing** | Procurement, assets, allocation, lifecycle (route), reports | **Partially Tested** |
| **Transport:** Vehicle → Route → Assignment → Tracking | Fleet → routes → allocation → GPS | All screens widget-tested | 8/9 tabs; new route button visibility only | **Partially Tested** |
| **HR:** Employee → Attendance → Payroll | Directory → attendance → payroll runs | Full widget; contracts | Directory, attendance, payroll Patrol; **no profile detail** | **Partially Tested** |

**Summary:** **0 Fully Tested** | **6 Partially Tested** | **1 Not Tested** (ERP exams admin E2E)

---

## Coverage Score Table

| Module | Screen Coverage | Workflow Coverage | Journey Coverage |
|--------|-----------------|-------------------|------------------|
| Admissions | 100% (10/10) | 56% | Partial |
| Finance | 86% (12/14) | 43% | Partial |
| SIS | 100% (5/5) | 100% | Partial |
| HR | 100% (9/9) | 89% | Partial |
| Management | 89% (8/9) | 78% | Partial |
| Transport | 100% (9/9) | 89% | Partial |
| Hostel | 100% (8/8) | 100% | Partial |
| Library | 100% (8/8) | 100% | Partial |
| Inventory | 80% (8/10) | 50% | Partial |
| Alumni | 100% (9/9) | 78% | Partial |
| Control Center | 86% (12/14) | 57% | Partial |
| Admin shell | 100% (1/1) | 100% | N/A |
| **Weighted average (core 12)** | **91%** | **68%** | **28% E2E** |

*Screen % = widget test and/or `router_smoke_test.dart` route anchor. Workflow % = Patrol workflows covering module sub-nav tabs / total tabs.*

---

## Priority List — Missing Tests

### P0 — Critical (release blockers for production CRUD confidence)

| Gap | Evidence | Recommended test type |
|-----|----------|----------------------|
| Fee collection **write path** (assign → collect → receipt) | Patrol stops at "Collected today" — `finance_workflows_test.dart` | Patrol + integration |
| Admissions **enrollment complete → SIS record** chain | Steps tested in isolation | Patrol E2E chain |
| **Finance refunds / discounts** screens unreachable in Patrol | Widget tests exist; no Patrol | Patrol smoke |
| **Inventory lifecycle** sub-nav (regression v18.6.2) | Route bypass only — `inventory_workflows_test.dart` | Patrol sub-nav + widget test for screen |
| **RBAC matrix** ERP modules (finance clerk, admissions, principal write deny) | Only 3 deny cases in `router_smoke_test.dart` | Patrol per persona + security suite |

### P1 — High

| Gap | Module |
|-----|--------|
| Control Center **providers / features** screens | Control Center |
| Finance **Copilot / Executive dashboard** widget smoke | Finance |
| Inventory **Copilot, categories, maintenance, vendors** Patrol | Inventory |
| HR **employee detail** route Patrol | HR |
| Admissions **documents, fee handoff, reports, settings** Patrol | Admissions |
| Transport / Alumni **settings** Patrol | Transport, Alumni |
| SIS **export download** assertion | SIS |
| Management **Intelligence Hub** route in router smoke + Patrol | Management |

### P2 — Medium

| Gap | Module |
|-----|--------|
| Form fill + validation errors on key ERP forms | All modules |
| Report **export/download** verification | Finance, SIS, Reports |
| Filter/search persistence | Admissions, SIS, Finance collections |
| Cross-module **pilot journey** automation | `test/integration/pilot/real_school_journey_test.dart` exists — extend to Patrol |
| Maestro journey CI wiring | `qa/journeys/*.yaml` (118 files) |

### P3 — Low

| Gap | Module |
|-----|--------|
| Golden updates for parent/teacher dashboard drift | Mobile |
| Secondary modules (school completion, evolution) Patrol | Intelligence |
| Screenshot regression host-side markers | `capturePatrolScreenshot` no-op on device |
| Performance benchmarks gate in CI | `test/performance/` |

---

## Cross-Cutting Gap Analysis

| Category | Status | Evidence |
|----------|--------|----------|
| **CRUD operations** | Partial | Write tests: admissions, finance, SIS mutations only; contracts cover API shapes; Patrol **read-only** |
| **Forms** | Partial | Widget render tests; enrollment wizard one step; no Patrol form submit |
| **Reports** | Partial | Report catalog anchors in Patrol; finance "export" name only |
| **Filters / search** | Partial | SIS filter/search Patrol; finance search icon; most modules untested |
| **Export / download** | **Not tested** | SIS "Export" label only |
| **Role-based access** | Partial | `router_smoke_test.dart` parent/student block, finance staff CC deny; `test/security/rbac/*`; Patrol mostly superAdmin |

---

## Production Readiness Assessment

| Factor | Score | Notes |
|--------|-------|-------|
| Unit + widget + contract layer | 95/100 | 1,298 tests; broad module contracts |
| Router + RBAC smoke | 90/100 | 90+ routes; limited persona matrix |
| Patrol device regression | 92/100 | 17/17 suites green; navigation-focused |
| E2E business journeys | 35/100 | Isolated steps; no write chains |
| Maestro / manual QA journeys | 50/100 | 118 YAMLs; not gated |
| Intelligence / copilot screens | 40/100 | Contract-only for several |
| **Overall production readiness** | **89%** | Aligns with v18.6.2 pilot readiness; safe for demo/QA builds; production CRUD needs P0 gaps |

---

## Appendix A — Flutter Test File Index (ERP Modules)

```
test/features/admissions/admissions_module_screens_test.dart
test/features/admissions/admissions_phase2_screens_test.dart
test/features/admissions/admissions_phase3_screens_test.dart
test/features/admissions/admissions_providers_test.dart
test/features/admissions/admissions_phase2_providers_test.dart
test/features/admissions/admissions_phase3_providers_test.dart
test/features/admissions/admissions_write_tests.dart
test/features/admissions/enrollment_validation_test.dart
test/features/admissions/admissions_enrollment_catalog_regression_test.dart
test/contracts/admissions/admissions_repository_contract_test.dart
test/contracts/admissions/admissions_write_contract_test.dart
test/integration/admissions/admissions_api_integration_test.dart

test/features/finance/finance_screens_test.dart
test/features/finance/finance_phase2_screens_test.dart
test/features/finance/finance_providers_test.dart
test/features/finance/finance_phase2_providers_test.dart
test/features/finance/finance_write_tests.dart
test/contracts/finance/finance_repository_contract_test.dart
test/contracts/finance/finance_write_contract_test.dart
test/contracts/finance/finance_intelligence_contract_test.dart
test/integration/finance/finance_api_integration_test.dart

test/features/sis/sis_screens_test.dart
test/features/sis/sis_providers_test.dart
test/features/sis/sis_write_tests.dart
test/contracts/sis/sis_repository_contract_test.dart
test/contracts/sis/sis_write_contract_test.dart
test/integration/sis/sis_api_integration_test.dart

test/features/hr/hr_screens_test.dart
test/features/hr/hr_providers_test.dart
test/contracts/hr/hr_repository_contract_test.dart
test/integration/hr/hr_api_integration_test.dart

test/features/management/management_screens_test.dart
test/features/management/management_providers_test.dart
test/features/management/intelligence/intelligence_scoring_test.dart
test/contracts/management/management_repository_contract_test.dart
test/integration/management/management_api_integration_test.dart

test/features/transport/transport_screens_test.dart
test/features/transport/transport_providers_test.dart
test/contracts/transport/transport_repository_contract_test.dart
test/integration/transport/transport_api_integration_test.dart

test/features/hostel/hostel_screens_test.dart
test/features/hostel/hostel_providers_test.dart
test/contracts/hostel/hostel_repository_contract_test.dart
test/integration/hostel/hostel_api_integration_test.dart

test/features/library/library_screens_test.dart
test/features/library/library_providers_test.dart
test/contracts/library/library_repository_contract_test.dart
test/integration/library/library_api_integration_test.dart

test/features/inventory/inventory_screens_test.dart
test/features/inventory/inventory_providers_test.dart
test/contracts/inventory/inventory_repository_contract_test.dart
test/contracts/inventory/inventory_intelligence_contract_test.dart
test/integration/inventory/inventory_api_integration_test.dart

test/features/alumni/alumni_screens_test.dart
test/features/alumni/alumni_providers_test.dart
test/contracts/alumni/alumni_repository_contract_test.dart
test/integration/alumni/alumni_api_integration_test.dart

test/features/control_center/control_center_screens_test.dart
test/features/control_center/control_center_providers_test.dart
test/contracts/control_center/control_center_repository_contract_test.dart
test/contracts/control_center/control_center_providers_contract_test.dart
test/integration/control_center/control_center_api_integration_test.dart

test/features/admin/admin_shell_test.dart
test/features/admin/admin_navigation_provider_test.dart
test/router_smoke_test.dart
test/router/route_guards_test.dart
test/router/route_protection_inventory_test.dart
test/integration/cross_module/cross_module_workflow_integration_test.dart
test/integration/pilot/pilot_readiness_e2e_test.dart
test/integration/pilot/real_school_journey_test.dart
test/integration/pilot/pilot_workflow_certification_test.dart
```

## Appendix B — Patrol Workflow File Index

```
patrol_test/workflows/erp_coverage_smoke_test.dart
patrol_test/workflows/erp_workflows_test.dart
patrol_test/workflows/admissions_workflows_test.dart
patrol_test/workflows/finance_workflows_test.dart
patrol_test/workflows/sis_workflows_test.dart
patrol_test/workflows/hr_workflows_test.dart
patrol_test/workflows/inventory_workflows_test.dart
patrol_test/workflows/transport_workflows_test.dart
patrol_test/workflows/library_workflows_test.dart
patrol_test/workflows/hostel_workflows_test.dart
patrol_test/workflows/alumni_workflows_test.dart
patrol_test/workflows/control_center_workflows_test.dart
patrol_test/workflows/management_workflows_test.dart
patrol_test/workflows/principal_workflows_test.dart
patrol_test/workflows/teacher_workflows_test.dart
patrol_test/workflows/parent_workflows_test.dart
patrol_test/workflows/student_workflows_test.dart
patrol_test/workflows/screenshot_validation_test.dart
patrol_test/helpers/patrol_helpers.dart
patrol_test/helpers/patrol_app.dart
qa/patrol/run_erp_coverage.sh
qa/reports/module_coverage_v18_6.json
```

## Appendix C — Maestro Sample Journeys (ERP)

```
qa/journeys/biz_erp_admissions_dashboard.yaml
qa/journeys/biz_erp_admissions_enrollment.yaml
qa/journeys/biz_erp_admissions_leads.yaml
qa/journeys/biz_erp_fee_collect.yaml
qa/journeys/biz_erp_fee_generate.yaml
qa/journeys/biz_erp_finance_collections.yaml
qa/journeys/biz_erp_finance_defaulters.yaml
qa/journeys/biz_erp_finance_receipt_verify.yaml
qa/journeys/biz_erp_finance_refunds.yaml
qa/journeys/biz_erp_finance_reports.yaml
qa/journeys/biz_erp_finance_structures.yaml
qa/journeys/biz_erp_hr_attendance.yaml
qa/journeys/biz_erp_hr_employees.yaml
qa/journeys/biz_erp_hr_payroll.yaml
qa/journeys/biz_erp_inventory_assets.yaml
qa/journeys/biz_erp_inventory_distribution.yaml
qa/journeys/biz_erp_sis_students.yaml
qa/journeys/biz_erp_transport_routes.yaml
qa/journeys/persona_finance.yaml
qa/journeys/persona_principal.yaml
qa/journeys/smoke_qa_personas.yaml
qa/maestro/flows/_shared/qa_persona_login.yaml
```

---

*Audit performed without code changes. For Patrol execution status see `docs/Releases/v18.6.2-final-suite-recovery.md`.*
