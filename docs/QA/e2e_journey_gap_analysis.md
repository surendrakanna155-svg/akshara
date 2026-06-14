# E2E Journey Gap Analysis — Akshara ERP

**Date:** 13 June 2026  
**Baseline:** v18.6.2-final-suite-recovery (`18.6.2+187`)  
**Companion audit:** [`coverage_audit_v18.7.md`](coverage_audit_v18.7.md)  
**Scope:** Seven canonical ERP business journeys (P0 list)  
**Method:** Static codebase + test inventory review — **no tests implemented in this pass**

---

## Executive Summary

Akshara ERP has **91% screen coverage** and **68% workflow (Patrol navigation) coverage**, but only **~28% end-to-end journey coverage**. The gap is structural: Patrol validates route reachability and anchor text under `QaLoginPersona.superAdmin`; it almost never validates **form submission, persistence, cross-module handoffs, or post-mutation UI state**.

| Journey | Current E2E score | Classification | Primary blocker |
|---------|-------------------|----------------|-----------------|
| 1. Admission | **~32%** | Partial | Steps isolated; no chained Lead → SIS write path |
| 2. Fee | **~22%** | Partial | `createCollection` exists in repository but **no UI mutation layer** |
| 3. Attendance | **~48%** | Partial | Only journey with a real Patrol write (teacher submit); no ERP academic chain |
| 4. Exam | **~12%** | Not tested (ERP admin) | No ERP exam-creation / marks-entry admin module |
| 5. HR | **~24%** | Partial | Read-only Patrol; no HR mutation providers |
| 6. Inventory | **~28%** | Partial | Procurement/lifecycle reachable; no stock-write Patrol |
| 7. Transport | **~30%** | Partial | Fleet/route tabs covered; no assignment or route-create submit |

**Weighted average (7 journeys): ~28%** — matches the v18.7 audit.

**Target:** 60%+ E2E journey coverage requires **fully automating 3–4 journeys** (or substantially completing 4–5). Navigation-only Patrol additions will not move this metric.

---

## Scoring Methodology

Each journey is decomposed into **canonical steps** (from the P0 brief). A step scores:

| Level | Weight | Meaning |
|-------|--------|---------|
| **Full** | 1.0 | Patrol or integration test performs write + asserts persisted outcome |
| **Partial** | 0.5 | Screen/widget/contract covered; Patrol reaches anchor only |
| **None** | 0.0 | No automated coverage |

Journey score = sum(step weights) / step count × 100.

Evidence sources: `patrol_test/workflows/*`, `test/features/*`, `test/contracts/*`, `test/integration/*`, `qa/journeys/*.yaml`, `lib/core/testing/qa_test_keys.dart`.

---

## Cross-Cutting Findings

### What works today

| Capability | Evidence |
|------------|----------|
| QA persona login | `lib/features/auth/qa_login_screen.dart`, 7 personas |
| ERP navigation helpers | `patrol_test/helpers/patrol_helpers.dart` — `navigateErpWorkflow`, `goToErpRoute`, `tapModuleSubNav` |
| Sub-nav stable keys | `QaTestKeys.moduleSubNavTab(module, label)` on admissions, finance, etc. |
| One proven write Patrol | `teacher_workflows_test.dart` — mark attendance → Submit → success snackbar |
| Mock write repositories | `MockAdmissionsRepository`, `MockFinanceRepository`, `MockSisRepository` — contract-tested |
| Cross-module data parity | `test/integration/cross_module/cross_module_workflow_integration_test.dart`, `pilot_workflow_certification_test.dart` |

### Systemic gaps (all journeys)

| Gap | Impact |
|-----|--------|
| **`QaTestKeys` surface is minimal** (~15 keys) | Form fields, submit buttons, success toasts, and list row selectors lack stable keys |
| **Patrol = text anchors, not outcomes** | e.g. `'Collected today'` ≠ payment recorded |
| **`createCollection` has no mutation provider / workflow action** | Blocks full Fee journey E2E in UI |
| **HR / Transport / Inventory have no `*_mutations_provider.dart`** | Write E2E requires new feature wiring or repository-only integration tests |
| **Maestro YAML (118 files) is navigation smoke** | Opens module + screenshot; not CI-gated; mirrors Patrol gaps |
| **Export/download never asserted** | SIS Export label visible; no file/blob check |
| **RBAC matrix thin in Patrol** | superAdmin/principal dominate; finance clerk, admissions clerk untested on journeys |

### Recommended QA hook pattern (all journeys)

Add keys only where Patrol/Maestro must tap or assert — follow existing convention in `qa_test_keys.dart`:

```dart
// Pattern: qa_<module>_<action>_button / qa_<entity>_<field>
static const admissionsCreateLeadButton = ValueKey('admissions_create_lead_button');
static const financeAssignFeePlanButton = ValueKey('finance_assign_fee_plan_button');
static const financeCollectionSuccessBanner = ValueKey('finance_collection_success');
static const sisConvertEnrollmentButton = ValueKey('sis_convert_enrollment_button');
```

Pair each key with a **deterministic success anchor** (snackbar text, list row ID, or KPI delta) that mock repository mutations already produce.

### Shared test data (QA mock mode)

Build with `./scripts/qa/build_qa_apk.sh` (`ENABLE_QA_LOGIN=true`, `ENABLE_API_MODE=false`, mock repositories).

| Fixture | Source | Use |
|---------|--------|-----|
| Demo lead | `Ananya Reddy`, `LD-1042` | Admissions lead → application chain |
| Pending enrollment | `MockAdmissionsRepository.getPendingEnrollments` | Enrollment wizard + approval |
| Approval queue | `Ananya Reddy` in approval Patrol anchor | Approval step |
| SIS conversion queue | `sis.getAdmissionsConversion` — non-empty queue | SIS conversion step |
| Finance handoffs | `getApprovedHandoffs` + `financePendingHandoffs` | Fee assignment |
| Pre-seeded collections | `getCollections` — read-only today | Receipt lookup baseline |
| Teacher class | `class-8a-p1`, student `Ravi Kumar` | Attendance mark/submit |
| Parent fees | `parent.getFees` — pending amount | Parent Pay Now smoke |
| Transport routes | Mock transport dashboard | Route/allocation screens |

For staging E2E (future): `docs/Testing/Demo-Accounts.md` — principal `9876543210`, 500 students, 30-day attendance seed.

---

## Journey 1 — Admission

**Canonical path:** Lead → Application → Admission (enrollment + approval) → Student record (SIS)

### Existing coverage

| Step | Flutter / contract | Patrol | Score |
|------|-------------------|--------|-------|
| Lead pipeline | Widget 10/10 screens; `createLead` contract + RBAC deny unit test | `admissions_workflows_test.dart` — `'New Lead'` anchor | Partial |
| Application queue | Widget + `submitApplication` contract | `'New Application'` anchor | Partial |
| Enrollment wizard | Widget multi-step; `submitEnrollment` contract | Steps 1–2 via `tapEnrollmentContinue` → `'Parent / guardian'` | Partial |
| Approval | Widget + `approveAdmission` contract | `'Ananya Reddy'` in approval queue | Partial |
| SIS student record | `createStudent` contract; `sis_write_tests` RBAC | **Separate** workflow: `sis admissions conversion` tab — anchor only | Partial |
| **Cross-module chain** | `cross_module_workflow_integration_test` — handoff ↔ accounts data parity | **None** | None |

**Journey score: ~32%**

### Missing coverage

- Patrol chain: create lead → convert to application → complete enrollment → approve → convert in SIS → verify student in registry
- Form fill on lead/application/enrollment steps (only Continue button keyed)
- Documents, fee handoff, reports, settings tabs (no Patrol)
- Principal write-deny on approval (RBAC not exercised in device tests)
- Post-conversion assertion: new student visible in SIS registry with generated admission number (`generateAdmissionNumber` in `sis_admissions_integration_provider.dart`)

### Required test data

- Fresh lead payload: `{ parentName, studentName, classLabel, phone }` — contract defaults work
- Link lead `LD-1042` → application → enrollment record in mock store
- Pending conversion row in SIS queue after approval

### Required QA hooks

| Key / hook | Location | Purpose |
|------------|----------|---------|
| `QaTestKeys.enrollmentContinueButton` | ✅ exists | Wizard advance |
| `admissions_create_lead_button` | Leads screen FAB | Open create form |
| `admissions_lead_save_button` | Lead form | Persist lead |
| `admissions_application_submit_button` | Applications | Submit application |
| `admissions_approve_button` | Approval panel | Approve admission |
| `sis_convert_enrollment_button` | SIS conversion screen | Trigger `completeSisEnrollmentConversion` |
| `sis_student_registry_row_{id}` | Registry list | Assert new student |

### Patrol feasibility

**High.** Admissions has **14 mutation providers** (`admissions_mutations_provider.dart`). Mock repo supports full write path. Longest chain (~8–12 min) fits Patrol; use `goToErpRoute` for module hops to avoid sub-nav flake.

### Maestro feasibility

**Medium.** YAML today (`biz_erp_admissions_leads.yaml`, `biz_erp_admissions_enrollment.yaml`) stops at module open + screenshot. Multi-step form fill is readable in YAML but needs keys/text targets; no write assertions.

### Estimated effort

| Work item | Effort |
|-----------|--------|
| QA keys on 6 touchpoints | 1–2 days (Agent B) |
| Single Patrol E2E chain test | 2–3 days (Agent E) |
| Maestro mirror + CI smoke | 1–2 days |
| RBAC deny variant (principal) | 1 day |
| **Total** | **5–8 days** |

---

## Journey 2 — Fee

**Canonical path:** Student → Fee assignment → Collection → Receipt → Ledger/report

### Existing coverage

| Step | Flutter / contract | Patrol | Score |
|------|-------------------|--------|-------|
| Fee structure | Widget; `createFeeStructure` mutation + contract | `'Create structure'` CTA visible | Partial |
| Fee assignment | Widget; `assignFeePlan` / `executeAssignFeePlan` with snackbar | `'Generate student fee account'` anchor | Partial |
| Collection (write) | `createCollection` in **repository + contract DTO**; **no** `finance_mutations_provider` entry | `'Collected today'` — KPI text only | None |
| Receipt lookup | Collection detail widget | Search icon visible in collections | Partial |
| Reports / ledger | Reports widget | `'Report catalog'` — no export | Partial |
| Admissions handoff | `cross_module_workflow_integration_test` | Fee assignment screen shows handoff queue in widget tests | Partial |

**Journey score: ~22%**

### Missing coverage

- **Product gap:** UI workflow for `FinanceRepository.createCollection` (repository ready; `finance_workflow_actions.dart` has assign/refund/structure but not collect)
- Patrol: assign fee plan → collect payment → open receipt → verify amount in reports
- Refund/discount approval chain (mutations exist; no Patrol)
- Finance clerk persona journey (`persona_finance.yaml` — navigation only)
- Parent mobile `Pay Now` smoke stops at `'Pay Fee'` dialog — no payment completion

### Required test data

- Approved handoff from admissions (`HO-*` ids in mock finance handoff queue)
- Fee structure + installment plan IDs from mock (`fee_std`, quarterly plan)
- Invoice ID post-assignment for `CreateCollectionRequest` (`inv-*` in mock store)
- Expected receipt number pattern from `MockFinanceRepository.createCollection`

### Required QA hooks

| Key / hook | Status |
|------------|--------|
| `finance_assign_fee_plan_button` | Needed on assignment panel |
| `finance_collect_payment_button` | Needed — **blocked until UI exists** |
| `finance_collection_amount_field` | Collection dialog |
| `finance_collection_confirm_button` | Submit collection |
| `QaTestKeys.receiptHistoryButton` | ✅ exists — wire to post-collection navigation |
| `finance_report_export_button` | Reports export action |

### Patrol feasibility

**Medium (blocked).** Assignment portion is Patrol-ready once keyed. **Collection step requires feature work first** (`createCollectionProvider` + screen/dialog). After that, Patrol is high feasibility — mock repo fully implements writes.

### Maestro feasibility

**Medium.** `biz_erp_fee_collect.yaml`, `biz_erp_fee_generate.yaml`, `biz_erp_finance_receipt_verify.yaml` — scroll-to-text only. Suitable for demo recording after Patrol defines stable selectors.

### Estimated effort

| Work item | Effort |
|-----------|--------|
| **Feature:** collection mutation UI | 3–5 days (Agent B) |
| QA keys + Patrol assign → collect → receipt | 3–4 days |
| Report catalog assertion (count/KPI delta) | 1–2 days |
| Maestro + finance clerk persona | 1–2 days |
| **Total** | **8–13 days** (includes feature gap) |

---

## Journey 3 — Attendance

**Canonical path:** Student → Attendance entry → Summary → Reports

### Existing coverage

| Step | Flutter / contract | Patrol | Score |
|------|-------------------|--------|-------|
| Student context | SIS registry; teacher roster | Teacher `'Ravi Kumar'` in class list | Partial |
| Attendance entry (write) | `teacher_attendance_provider.submitAttendance` | ✅ **`teacher_workflows_test`** + **`erp_coverage_smoke_test`** — Submit → `'Attendance submitted successfully.'` | **Full** |
| Summary | Parent attendance KPI (`attendancePercent`); student dashboard card | Parent/student `'Attendance'` anchors — read only | Partial |
| Reports | No dedicated ERP academic attendance module | HR staff attendance + transport pickup attendance — unrelated anchors | Partial |
| Cross-persona visibility | Mock parent `getAttendance` in `real_school_journey_test` | **No** teacher-submit → parent-summary chain | None |

**Journey score: ~48%** (highest of the seven)

### Missing coverage

- Single Patrol chain: teacher submit → switch persona parent → verify updated monthly %
- ERP academic attendance reports (module absent — journey spans mobile + HR staff only)
- Save draft vs submit distinction
- Attendance report export (management analytics enrollment ≠ attendance report)

### Required test data

- Class `class-8a-p1`, students with known baseline marks
- Parent linked to same student as teacher roster
- Month filter: `DateTime(2026, 6, 1)` — used in integration tests

### Required QA hooks

| Key / hook | Status |
|------------|--------|
| `teacher_attendance_all_present_button` | Needed (currently text `'All present'`) |
| `teacher_attendance_submit_button` | Needed (text `'Submit'`) |
| `teacher_attendance_success_snackbar` | Assert key on snackbar |
| `parent_attendance_kpi_percent` | KPI strip assert after sync |

### Patrol feasibility

**Very high for mobile chain.** Only journey with proven write Patrol. Extending to parent verification is ~1–2 extra persona switches. No feature gaps.

### Maestro feasibility

**High for mobile.** Teacher YAML flows feasible; ERP HR attendance is separate staff journey (`biz_erp_hr_attendance.yaml` — smoke only).

### Estimated effort

| Work item | Effort |
|-----------|--------|
| QA keys on teacher attendance actions | 0.5–1 day |
| Patrol teacher → parent chain | 2–3 days |
| Optional: management analytics attendance drill | 1–2 days |
| **Total** | **3–6 days** |

---

## Journey 4 — Exam

**Canonical path:** Exam creation → Marks entry → Result generation → Report card

### Existing coverage

| Step | Flutter / contract | Patrol | Score |
|------|-------------------|--------|-------|
| Exam creation (ERP admin) | **No dedicated ERP exam admin module** in core 12 drawers | None | None |
| Marks entry | `lib/features/education/` — homework/question papers; school completion lesson logs | None in ERP Patrol | None |
| Result generation | `lib/features/intelligence/exam/` — analytics providers + contracts | Maestro `biz_erp_exam_reports.yaml` scrolls to `'Exam'` under **Management** | Partial |
| Report card | Parent/student mobile exams screens | Teacher/parent/student `'Exams'` anchors | Partial |

**Journey score: ~12%**

### Missing coverage

- Entire ERP admin path (create exam schedule, enter marks, publish results)
- Teacher marks entry write (mobile exams screen is read-only in Patrol)
- Result publish → parent notification → report card PDF/export
- Staging seed validates exam **read** APIs (`Demo-Accounts.md`) — not wired to Patrol

### Required test data

- Exam schedule items in `MockParentRepository` / education mock
- Question paper + marks payload for education module
- Published result linking student + subject grades

### Required QA hooks

| Key / hook | Notes |
|------------|-------|
| ERP exam module screens | **Product gap** — may live under school completion / education, not ERP drawer |
| `education_create_exam_button` | Education screen |
| `education_marks_save_button` | Marks grid |
| `parent_exam_results_section` | Parent exams results tab |

### Patrol feasibility

**Low (ERP path).** Mobile read Patrol works. Full journey needs **product scoping**: where ERP exam admin lives (Management vs School Completion vs Education hub). Cannot E2E without screen inventory decision.

### Maestro feasibility

**Low–medium.** `biz_erp_exam_reports.yaml` proves Management module reaches exam analytics label — not a journey.

### Estimated effort

| Work item | Effort |
|-----------|--------|
| Product: ERP exam admin route map | 2–3 days discovery + spec |
| Feature + mutations (if missing) | 5–10 days |
| Patrol mobile read chain (teacher → parent) | 2–3 days |
| Full ERP exam E2E | **15–20 days** |

---

## Journey 5 — HR

**Canonical path:** Employee → Attendance → Payroll → Salary output

### Existing coverage

| Step | Flutter / contract | Patrol | Score |
|------|-------------------|--------|-------|
| Employee directory | Widget 9/9; contract read | `'Employee directory'` | Partial |
| Staff attendance | Widget + contract | `'Staff attendance'` | Partial |
| Payroll runs | Widget + contract | `'Payroll runs'` | Partial |
| Salary output / payslip | Employee detail route in router smoke; **no Patrol** | None | None |

**Journey score: ~24%**

### Missing coverage

- Employee create/edit, attendance mark, payroll run approve/process
- Employee detail route Patrol (`hrEmployeeDetail`)
- Payslip download / salary register report
- No `hr_mutations_provider.dart` in codebase

### Required test data

- Mock HR employee IDs from `MockHrRepository`
- Payroll run in `draft` / `approved` states
- Expected net pay figures for assertion

### Required QA hooks

| Key / hook | Purpose |
|------------|---------|
| `hr_create_employee_button` | Directory FAB |
| `hr_mark_attendance_button` | Staff attendance |
| `hr_run_payroll_button` | Payroll processing |
| `hr_payslip_row_{id}` | Salary output list |

### Patrol feasibility

**Low until mutations exist.** Read navigation is done. Write E2E requires HR mutation layer (repository may support writes — verify contract tests) + UI wiring.

### Maestro feasibility

**Medium for smoke.** `biz_erp_hr_employees.yaml`, `biz_erp_hr_attendance.yaml`, `biz_erp_hr_payroll.yaml` — module open only.

### Estimated effort

| Work item | Effort |
|-----------|--------|
| HR mutation providers + UI actions (if absent) | 5–8 days |
| QA keys + Patrol read chain (directory → payroll) | 2 days |
| Patrol write payroll run | 3–4 days |
| **Total** | **10–14 days** |

---

## Journey 6 — Inventory

**Canonical path:** Purchase → Stock entry → Asset lifecycle → Reports

### Existing coverage

| Step | Flutter / contract | Patrol | Score |
|------|-------------------|--------|-------|
| Purchase / PO | Widget; procurement tab | `'Purchase orders'` | Partial |
| Stock / assets | Widget; assets registry | `'Asset registry'` | Partial |
| Asset lifecycle | Lifecycle screen — widget test **missing**; Patrol uses `navigateErpModuleRoute` + `QaTestKeys.inventoryLifecycleScreen` | Route bypass only (sub-nav regression v18.6.2) | Partial |
| Reports | Widget | `'Report catalog'` | Partial |
| Book distribution | `MockInventoryDistributionRepository` in pilot tests | Distribution lifecycle anchor `'Assets tracked'` | Partial |

**Journey score: ~28%**

### Missing coverage

- PO create/receive, asset allocate, lifecycle state transition writes
- Categories, maintenance, vendors, copilot tabs (no Patrol)
- Lifecycle sub-nav path (not only route bypass)
- Distribution issue/return transaction

### Required test data

- PO draft in mock inventory store
- Asset SKU + quantity for receive
- Lifecycle asset ID for state transition

### Required QA hooks

| Key / hook | Status |
|------------|--------|
| `QaTestKeys.inventoryLifecycleScreen` | ✅ exists |
| `inventory_create_po_button` | Needed |
| `inventory_receive_stock_button` | Needed |
| `inventory_allocate_asset_button` | Needed |
| `inventory_lifecycle_advance_button` | State transition |

### Patrol feasibility

**Medium.** Lifecycle route bypass pattern proven. Writes need mutation providers (inventory has contracts; check write methods in `inventory_repository`).

### Maestro feasibility

**Medium.** `biz_erp_inventory_assets.yaml`, `biz_erp_inventory_distribution.yaml` — smoke.

### Estimated effort

| Work item | Effort |
|-----------|--------|
| Lifecycle widget test + sub-nav Patrol fix | 1–2 days |
| Mutation UI + keys for PO → receive → allocate | 5–7 days |
| Patrol E2E chain | 3–4 days |
| **Total** | **9–13 days** |

---

## Journey 7 — Transport

**Canonical path:** Vehicle → Route → Student assignment → Tracking

### Existing coverage

| Step | Flutter / contract | Patrol | Score |
|------|-------------------|--------|-------|
| Vehicle registry | Widget 9/9 | `'Vehicle registry'` | Partial |
| Route catalog | Widget | `'Route catalog'`, `'New route'` button visible | Partial |
| Student allocation | Widget | `'Student transport allocation'` | Partial |
| Tracking / telemetry | Widget | `'Vehicle telemetry'` | Partial |
| Pickup attendance | Widget | `'AM pickup attendance'` | Partial |

**Journey score: ~30%**

### Missing coverage

- Route create form submit, vehicle assign to route, student assign to seat/route
- GPS live tracking validation (mock telemetry read only)
- Transport settings tab (no Patrol)
- Settings + RBAC matrix

### Required test data

- Route ID, vehicle ID, student admission number from mock transport repo
- Allocation capacity constraints

### Required QA hooks

| Key / hook | Purpose |
|------------|---------|
| `transport_new_route_save_button` | Route form |
| `transport_assign_vehicle_button` | Fleet |
| `transport_assign_student_button` | Allocation panel |
| `transport_tracking_map_marker` | Optional — flaky on CI |

### Patrol feasibility

**Medium.** Navigation complete. Writes need transport mutation layer (no `transport_mutations_provider.dart` found).

### Maestro feasibility

**Medium.** `biz_erp_transport_routes.yaml` — smoke.

### Estimated effort

| Work item | Effort |
|-----------|--------|
| Transport mutations + UI | 4–6 days |
| QA keys + Patrol assignment chain | 3–4 days |
| Tracking assert (mock status badge vs map) | 1–2 days |
| **Total** | **8–12 days** |

---

## Priority Ranking

### P0 — Automate first (business critical + feasibility)

| Rank | Journey | Rationale |
|------|---------|-----------|
| **P0-1** | **Admission → SIS** | Foundational entity lifecycle; 14 mutation providers; cross-module tests exist; unlocks fee handoff; highest structural confidence gain per engineering day |
| **P0-2** | **Fee (assignment + collection)** | Revenue-critical; assignment UI ready; collection blocked on small feature gap; pairs naturally after P0-1 |
| **P0-3** | **Attendance (mobile chain)** | **Lowest effort, proven write pattern**; extends only existing success path; good parallel track |

### P1 — High value, higher cost

| Rank | Journey | Rationale |
|------|---------|-----------|
| **P1-1** | **Inventory** | Procurement → lifecycle is distinct ops path; lifecycle sub-nav debt from v18.6.2 |
| **P1-2** | **HR** | Payroll correctness; requires mutation layer build |
| **P1-3** | **Transport** | Safety/compliance; navigation already strong |

### P2 — Defer until product scope clear

| Rank | Journey | Rationale |
|------|---------|-----------|
| **P2-1** | **Exam (ERP admin)** | No ERP exam admin module; mobile read-only coverage misleading; largest product unknown |

---

## Recommended First Automation

### Primary: **Admission Journey E2E (Lead → Application → Enrollment → Approval → SIS conversion)**

**Why this yields the largest QA confidence increase:**

1. **Validates the foundational data pipeline** — every other journey assumes a student record exists.
2. **Write infrastructure is already built** — 14 admissions mutations + SIS `createStudent` / `completeSisEnrollmentConversion`; unlike Fee collection, no missing mutation provider for core steps.
3. **Cross-module handoff is the #1 production risk** called out in v18.7 audit — currently only mock data parity tests, not device E2E.
4. **Directly unlocks P0-2 Fee journey** — approved handoff → fee assignment queue populated.
5. **Estimated +12–14 points** on the 7-journey average (32% → ~95% for this journey when complete).

**Suggested Patrol spec (single test, ~10 min):**

```
superAdmin → create lead → create application from lead →
complete enrollment wizard (all steps) → approve in approval queue →
SIS Admissions Conversion → convert →
SIS Student Registry → assert admission number + student name
```

### Parallel quick win: **Attendance teacher submit → parent summary**

- **3–6 days**, proven pattern, **+6–8 points** on journey average.
- Does not replace Admission priority but can ship in the same sprint for morale + CI signal.

### Do not start with

- **Exam ERP admin** — product gap too large.
- **More navigation-only Patrol** — will not move E2E metric (explicit user constraint).

---

## Path to 60%+ E2E Coverage

| Phase | Journeys | Expected avg score | Cumulative avg |
|-------|----------|-------------------|----------------|
| Baseline | — | — | **28%** |
| Phase 1 | Admission full + Attendance chain | 32→90%, 48→85% | **~42%** |
| Phase 2 | Fee assign + collection (after UI) | 22→80% | **~52%** |
| Phase 3 | Inventory PO→lifecycle OR HR payroll | +1 journey to 75%+ | **~58–62%** |

**Gate criteria per journey (definition of “done”):**

- [ ] Patrol test performs ≥1 write per major step
- [ ] Asserts persisted state (list row, KPI, or snackbar keyed)
- [ ] Cross-module handoffs verified in same test where applicable
- [ ] Maestro YAML updated with same anchors (optional CI smoke)
- [ ] No new navigation-only `patrolTest` entries

---

## Implementation Ownership (per AGENTS.md)

| Work type | Agent |
|-----------|-------|
| QA keys on feature screens | B (ERP features) |
| Collection mutation UI (Fee gap) | B |
| HR/Transport/Inventory mutations | B + A (repository if API gap) |
| Patrol E2E test files | E |
| Contract tests for new write methods | A |
| RBAC persona variants | D + E |
| Doc update post-implementation | F |

---

## Appendix — Evidence Index

| Artifact | Path |
|----------|------|
| Coverage audit | `docs/QA/coverage_audit_v18.7.md` |
| Patrol workflows | `patrol_test/workflows/*.dart` |
| Patrol helpers | `patrol_test/helpers/patrol_helpers.dart` |
| QA keys | `lib/core/testing/qa_test_keys.dart` |
| Admissions mutations | `lib/features/admissions/admissions_mutations_provider.dart` |
| SIS conversion | `lib/features/sis/integration/sis_admissions_integration_provider.dart` |
| Finance workflow (no collect) | `lib/features/finance/finance_workflow_actions.dart` |
| Teacher attendance write | `patrol_test/workflows/teacher_workflows_test.dart` |
| Cross-module integration | `test/integration/cross_module/cross_module_workflow_integration_test.dart` |
| Maestro journeys | `qa/journeys/biz_erp_*.yaml` |
| Journey manifest | `qa/patrol/journey_manifest.json` |
| Patrol runner | `qa/patrol/run_erp_coverage.sh` |

---

*Planning document only — no tests or production code modified. Next step: implement Phase 1 Admission E2E per this spec.*
