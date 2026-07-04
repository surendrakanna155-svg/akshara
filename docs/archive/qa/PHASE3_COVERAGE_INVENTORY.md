# Phase 3 — QA Coverage Inventory

**Version:** 1.0  
**Date:** June 2026  
**Purpose:** Quantify remaining work before choosing **ERP feature completion** vs **exhaustive QA coverage**  
**Status:** Planning only — **no implementation in this document**

---

## Executive summary

Akshara ERP has **strong navigation/workflow Patrol coverage** (v18.6 module report) but **weak button-level and CRUD coverage**. The gap between “workflow smoke passed” and “every manage action verified” is large and explains why testing feels slow yet incomplete.

| Metric | Count | Notes |
|--------|------:|-------|
| **Screen files** (`*_screen.dart`) | **184** | All personas + ERP admin |
| **Canonical ERP module routes** (route list constants) | **102** | Admissions through Control Center |
| **Static route constants** (`RouteNames`) | **189** | Includes mobile, intelligence, school platform |
| **QaTestKeys definitions** | **79** | 70 static + 9 factory helpers |
| **`AksharaManageAction` placements** | **51** | Guarded write CTAs in UI |
| **Workflow dialogs** (`*_workflow_actions.dart`) | **25** | AlertDialog / confirm flows |
| **Mutation / CRUD operations** (providers) | **55** | Across 10 mutation modules + education |
| **Report surfaces** | **8** | Module report screens |
| **Export actions (PDF / queued)** | **5** | Finance, HR, Inventory, Transport, Education |
| **Patrol workflow suites** | **30** | In `patrol_test/workflows/` |
| **Dedicated Patrol E2E files** | **12** | Assert QA keys + snackbars |
| **Screen widget test files** | **20** | Module `*_screens_test.dart` |
| **`flutter test` cases (baseline)** | **~1,319** | CI gate; no emulator |

### Coverage classification totals (this inventory)

| Class | Meaning | QaTestKeys | CRUD ops | Workflow dialogs |
|-------|---------|----------:|---------:|-----------------:|
| **A** | Patrol E2E (device) | 63 | 16 | 11 |
| **B** | `flutter test` integration / write tests only | 13 | 1 | 1 |
| **C** | Widget test only (render / tap snackbar) | 0* | 3 | 0 |
| **D** | No automated coverage | 3 | 35 | 13 |

\*Phase 2 export keys are classified **B** (widget + integration-style tests, not Patrol).

### Uncovered (headline numbers)

| Gap | Uncovered count |
|-----|----------------:|
| CRUD / mutation operations without Patrol | **39** (55 − 16) |
| Workflow dialogs without Patrol | **14** |
| Manage CTAs without stable QA keys | **~31** (51 placements − ~20 keyed write flows) |
| Screens without dedicated widget test file | **~164** (184 screens − ~20 modules with screen tests) |
| Phase 2 exports / PO handoff without Patrol | **6** actions |
| Platform / “Other” routes (Patrol proxy) | **~60** of 65 routes at **7.7%** nav coverage |

**Important:** `qa/reports/module_coverage_v18_6.json` reports **100%** for several modules. That metric means **named workflow strings appear in Patrol suites**, not that every button or CRUD path is exercised. This document uses **button / key / mutation** granularity.

---

## Classification legend

| Class | Layer | Definition |
|-------|-------|------------|
| **A** | Patrol | QA build on emulator; journey asserts `QaTestKeys` or stable navigation outcome |
| **B** | Flutter integration / provider | `flutter test` — write tests, integration chains, Phase 1/2 completion tests |
| **C** | Widget only | Screen renders; optional snackbar tap; no provider chain or device |
| **D** | None | No automated test references the action |

---

## 1. QaTestKeys inventory

**Source:** `lib/core/testing/qa_test_keys.dart`  
**Stability tests:** `test/core/testing/qa_test_keys_test.dart`

### 1.1 Summary by class

| Class | Count | % of 79 |
|-------|------:|--------:|
| A | 63 | 80% |
| B | 13 | 16% |
| D | 3 | 4% |

### 1.2 Class A — Patrol-covered keys (63)

Auth & shell: `qaLoginScreen`, `loginPhoneField`, `loginContinueButton`, `otpField`, `otpVerifyButton`, `logoutButton`, `logoutConfirmButton`, `profileButton`, `receiptHistoryButton`, `erpMenuButton`, `erpNavModule(*)`, `moduleSubNavTab(*)`, `principalQuickAction(*)`, `qaPersonaButton(*)`

Admissions → Finance journey: `admissionsCreateLeadButton`, lead form fields, `admissionsLeadDialogCreateButton`, `admissionsLeadCreatedSnackbar`, `admissionsCreateApplicationButton`, `admissionsApplicationSubmittedSnackbar`, `enrollmentContinueButton`, `enrollmentStudentNameField`, `enrollmentSubmitButton`, `admissionsEnrollmentSubmittedSnackbar`, `admissionsApproveButton`, `admissionsApprovalQueueRow(*)`, `admissionsApprovedSnackbar`, `sisConvertEnrollmentButton`, `sisConversionSuccessSnackbar`, `sisRegistrySearchField`, `sisRegistryStudentRow(*)`, `financeHandoffQueueRow(*)`, `financeAssignFeePlanButton`, `financeFeeAccountCreatedSnackbar`, `financeRecordCollectionButton`, collection fields, `financeCollectionSubmitButton`, `financeCollectionSuccessSnackbar`, `financeReceiptSearchField`, `financeLastInvoiceIdField`

HR / Inventory / Transport / Education (Phase 1): `hrCreateLeaveButton`, `hrLeaveSuccessSnackbar`, `hrProcessPayrollButton`, `hrPayrollProcessedSnackbar`, `inventoryCreatePoButton`, `inventoryPoSuccessSnackbar`, `inventoryRecordLifecycleButton`, `inventoryLifecycleSuccessSnackbar`, `inventoryLifecycleScreen`, `transportSaveRouteButton`, `transportSaveRouteDialogButton`, `transportRouteSuccessSnackbar`, `transportActivateRouteButton`, `transportActivateRouteDialogButton`, `transportRouteActivatedSnackbar`, `educationPublishRemarkButton`, `educationRemarkPublishedSnackbar`

Teacher: `teacherAttendanceSubmitButton`, `teacherAttendanceSubmittedBanner`

### 1.3 Class B — Flutter test only (13)

Phase 2 exports & handoff (no Patrol yet):

| Key | Module | Test location |
|-----|--------|---------------|
| `hrPayrollExportPdfButton` / `hrPayrollExportSuccessSnackbar` | HR | `phase2_report_export_widget_test.dart` |
| `inventoryReportExportPdfButton` / `inventoryReportExportSuccessSnackbar` | Inventory | same |
| `transportReportExportPdfButton` / `transportReportExportSuccessSnackbar` | Transport | same |
| `educationReportCardExportButton` / `educationReportCardExportSuccessSnackbar` | Education | same |
| `inventoryPoReceiveHandoffButton(*)` / `inventoryPoReceiveHandoffDialogButton` / `inventoryPoReceiveHandoffSuccessSnackbar` | Inventory / Finance | `phase2_po_receive_handoff_widget_test.dart` |
| `financeReportExportPdfButton` / `financeReportExportSuccessSnackbar` | Finance | Nav-only in Patrol; export not asserted on device |

### 1.4 Class D — No coverage (3)

| Key | Reason |
|-----|--------|
| `splash` | Launch screen; smoke only, not in workflow assertions |
| `parentAttendanceKpiPercent` | Display KPI; no journey asserts value |
| `financeCollectionReceiptRow(*)` | Row key defined; Patrol searches receipts by text field, not row key |

### 1.5 Factory keys (9)

Parameterized helpers: `erpNavModule`, `principalQuickAction`, `moduleSubNavTab`, `qaPersonaButton`, `admissionsApprovalQueueRow`, `sisRegistryStudentRow`, `financeHandoffQueueRow`, `financeCollectionReceiptRow`, `inventoryPoReceiveHandoffButton` — coverage follows parent journey (mostly **A**, handoff **B**, receipt row **D**).

---

## 2. Routes & screens inventory

### 2.1 ERP module routes (102)

| Module | Routes | Screen test file | Patrol workflow suite |
|--------|-------:|:----------------:|:---------------------:|
| Admissions | 9 | Yes (3 files) | Yes |
| Finance | 13 | Yes | Yes |
| SIS | 5 | Yes | Yes |
| HR | 8 | Yes | Yes |
| Management | 10 | Yes | Yes |
| Transport | 9 | Yes | Yes |
| Hostel | 8 | Yes | Yes |
| Library | 8 | Yes | Yes |
| Inventory | 10 | Yes | Yes |
| Alumni | 8 | Yes | Yes |
| Control Center | 14 | Partial | Yes |

### 2.2 Additional route groups (not in module lists)

| Group | Approx. routes | Patrol proxy coverage (v18.6) |
|-------|---------------:|------------------------------:|
| Parent mobile | 12 | 100% |
| Teacher mobile | 8 | 100% |
| Student mobile | 8 | 100% |
| Intelligence / 360 / Copilot | 15+ | Partial |
| School completion / Phase 4–5 | 20+ | Low (**Other** bucket 7.7%) |
| Auth | 6 | Smoke only |

### 2.3 Screen files without module screen-test coverage (16 feature areas)

No dedicated `test/features/<module>/*_screens_test.dart`:

`academic`, `admin`, `auth`, `copilot`, `employee`, `evolution`, `homework_intelligence`, `intelligence`, `inventory_distribution`, `memories`, `notifications`, `onboarding`, `operations`, `promotion`, `school_completion`, `student_360`

**~164 screens** lack a file-level widget test inventory (many ERP modules test a subset of screens only).

---

## 3. Manage / write actions inventory

**Pattern:** `AksharaManageAction` + `Permission.manage*`  
**Total placements:** 51 (grep across `lib/features/`)

### 3.1 Keyed write actions (Patrol or widget)

| Action | Module | Key | Class |
|--------|--------|-----|-------|
| Process payroll | HR | `hrProcessPayrollButton` | A |
| Export payroll PDF | HR | `hrPayrollExportPdfButton` | B |
| Create leave | HR | `hrCreateLeaveButton` | A |
| Create PO | Inventory | `inventoryCreatePoButton` | A |
| Record lifecycle | Inventory | `inventoryRecordLifecycleButton` | A |
| PO receive handoff | Inventory | `inventoryPoReceiveHandoffButton` | B |
| Export inventory report | Inventory | `inventoryReportExportPdfButton` | B |
| Save / activate route | Transport | `transportSaveRouteButton`, `transportActivateRouteButton` | A |
| Export transport report | Transport | `transportReportExportPdfButton` | B |
| Publish remark | Education | `educationPublishRemarkButton` | A |
| Export report card | Education | `educationReportCardExportButton` | B |
| Assign fee plan | Finance | `financeAssignFeePlanButton` | A |
| Record collection | Finance | `financeRecordCollectionButton` | A |
| Create lead / approve / etc. | Admissions | multiple | A |

### 3.2 Manage actions **without** QA keys (Class D — sample)

Estimated **~31** guarded buttons lack `QaTestKeys`, including:

- Finance: fee structure create/edit, refund approve/reject, scholarship CRUD, settings edit
- Admissions: counselor assign, stage change, notes, follow-ups, document approve/reject (partial Patrol)
- SIS: student create/update, academic assign (convert enrollment keyed; others not)
- Teacher: homework review, exam marks, leave, messaging
- Parent: payment initiate/confirm, leave submit
- Student: homework submit
- Inventory finance reconciliation: approve PO, receive goods (Finance screen — no UI keys)
- Most Control Center / School platform manage surfaces

---

## 4. CRUD / mutation operations inventory

**Source:** `*_mutations_provider.dart`, `education_provider.dart`, `inventory_finance_mutations_provider.dart`

### 4.1 Summary

| Module | Operations | A | B | C | D |
|--------|----------:|--:|--:|--:|--:|
| Admissions | 14 | 4 | 0 | 0 | 10 |
| Finance | 12 | 2 | 0 | 0 | 10 |
| SIS | 5 | 1 | 0 | 0 | 4 |
| HR | 2 | 2 | 0 | 0 | 0 |
| Inventory | 3 | 2 | 1 | 0 | 0 |
| Transport | 2 | 2 | 0 | 0 | 0 |
| Inventory–Finance | 2 | 0 | 0 | 0 | 2 |
| Teacher | 6 | 1 | 0 | 0 | 5 |
| Parent | 3 | 0 | 0 | 0 | 3 |
| Student | 1 | 0 | 0 | 0 | 1 |
| Education | 5 | 1 | 0 | 3 | 1 |
| **Total** | **55** | **16** | **1** | **3** | **35** |

### 4.2 Class A operations (16) — Patrol or E2E journey

`createLead`, `submitApplication`, `submitEnrollment`, `approveAdmission`, `sendToFinance`, `convertAdmissionsEnrollment`, `assignFeePlan`, `createCollection`, `createLeave`, `processPayrollRun`, `createProcurementOrder`, `recordAssetLifecycleEvent`, `createTransportRoute`, `activateTransportRoute`, `publishRemark`, `submitClassAttendance`

### 4.3 Class B operations (1)

`receiveProcurementHandoff` — integration via mock repos + widget test; finance `receiveGoods` called internally

### 4.4 Class D operations (35) — highest gap

Examples: all Finance fee-structure/refund/scholarship mutations; most Admissions lead-ops; SIS student CRUD; teacher homework/exam/message; parent payment; inventory-finance approve/receive on reconciliation UI; education `generatePaper` / `generateHomework` without device E2E.

---

## 5. Dialogs & forms inventory

**Source:** `*_workflow_actions.dart` (25 entry points)

| Module | Workflow | Class | Patrol |
|--------|----------|-------|--------|
| Admissions | `showCreateLeadDialog` | A | E2E journey |
| Admissions | `runApproveAdmission` | A | E2E journey |
| Admissions | `showAssignCounselorDialog` | D | — |
| Admissions | `showChangeLeadStageDialog` | D | — |
| Admissions | `showAddLeadNoteDialog` | D | — |
| Admissions | `showAddFollowUpDialog` | D | — |
| Admissions | `runApproveDocument` / `runRejectDocument` | D | — |
| Admissions | `runRejectAdmission` | D | — |
| Admissions | `runSendToFinance` | D | Partial (handoff tested downstream) |
| Finance | `showCreateFeeStructureDialog` | D | — |
| Finance | `showEditFeeStructureDialog` | D | — |
| Finance | `executeAssignFeePlan` | A | E2E |
| Finance | `showRecordCollectionDialog` | A | E2E |
| Finance | `approveSelectedRefund` / `rejectSelectedRefund` | D | — |
| Finance | `showCreateScholarshipDialog` | D | — |
| Finance | `showEditFinanceSettingDialog` | D | — |
| HR | `showCreateHrLeaveDialog` | A | E2E |
| HR | `showProcessPayrollRunDialog` | A | E2E |
| Inventory | `showCreateProcurementOrderDialog` | A | E2E |
| Inventory | `showRecordAssetLifecycleEventDialog` | A | E2E |
| Inventory | `submitProcurementReceiveHandoff` | B | Widget only |
| Transport | `showCreateTransportRouteDialog` | A | E2E |
| Transport | `showActivateTransportRouteDialog` | A | E2E |

**Forms with QA field keys:** admissions lead, enrollment, finance collection, login/OTP — **~15 fields keyed**; hundreds of other `TextField`s across ERP are **unkeyed (Class D)**.

---

## 6. Reports & exports inventory

### 6.1 Report screens (8)

| Screen | Route area | Widget test | Patrol nav |
|--------|------------|:-----------:|:----------:|
| `finance_reports_screen` | FN reports | Partial | Yes |
| `inventory_reports_screen` | INV reports | Yes | Yes |
| `transport_reports_screen` | TR reports | Yes | Yes |
| `admissions_reports_screen` | AD reports | Yes | Yes |
| `hostel_reports_screen` | HO reports | Yes | Yes |
| `library_reports_screen` | LB reports | Yes | Yes |
| `alumni_reports_screen` | AL reports | Yes | Yes |
| `management` analytics (partial) | MG | Yes | Yes |

Report **catalog row actions** (download icons on inventory) — render tested; **export tap not Patrol’d**.

### 6.2 Export actions (5)

| Export | UI pattern | Widget | Patrol | Class |
|--------|------------|:------:|:------:|-------|
| Finance report PDF | Snackbar queue | Partial | Nav only | B |
| HR payroll summary PDF | Snackbar queue | Yes | No | B |
| Inventory lifecycle/procurement PDF | Snackbar queue | Yes | No | B |
| Transport occupancy PDF | Snackbar queue | Yes | No | B |
| Education report card PDF | Snackbar queue | Yes | No | B |

**None** perform live PDF generation in pilot — all queue/mock snackbar pattern.

---

## 7. Patrol suite map (current)

| Suite type | Count | Runtime (observed) |
|------------|------:|-------------------:|
| Full regression (`ERP_COVERAGE_MODE=full`) | 25 passing suites | **~53 min** (1 emulator) |
| Fast smoke | 1 suite | **~2 min** |
| Dedicated E2E (`*_e2e_*`) | 12 files | **~2–4 min each** |
| CI Phase 1 Patrol job | 4 E2E files | **~15–25 min** |

Patrol helpers: `patrol_test/helpers/*_journey_helpers.dart` — admissions, finance, HR, inventory, transport, teacher.

---

## 8. Why testing is slow vs why gaps remain

| Factor | Effect |
|--------|--------|
| **Patrol = real APK + emulator** | 2–4 min minimum per suite; full regression ~1 hour |
| **Workflow coverage ≠ button coverage** | v18.6 “100%” = route names in workflow strings |
| **Only ~79 QA keys** vs **51 manage CTAs + hundreds of buttons** | Keys concentrated on 2–3 journeys per module |
| **35/55 CRUD ops Class D** | Provider exists; UI test missing |
| **Mock pilot** | Fast unit tests but no production API/DB validation |
| **Phase 2 delivered widget tests first** | Exports/handoff not yet in Patrol CI |

---

## 9. Estimates — remaining work

### 9.1 New Patrol journeys required

| Phase | Scope | New journeys | Cumulative Patrol suites |
|-------|-------|-------------:|-------------------------:|
| **Current** | Nav + core E2E | 0 | 30 |
| **3A** | Phase 2 parity on device + critical CRUD gaps | **12** | 42 |
| **3B** | All workflow dialogs + finance/admissions CRUD + mobile writes | **35** | 77 |
| **3C** | Per-screen smoke: every sub-nav tab + every `AksharaManageAction` + back stack | **120–150** | 200+ |

### 9.2 Runtime impact (single `emulator-5554`)

| Scenario | Est. duration | Notes |
|----------|--------------:|-------|
| Current CI `flutter test` | **~8–12 min** | No emulator |
| Current full Patrol | **~53 min** | Measured on `main` |
| + Phase 3A | **+30–45 min** | **~85–100 min** total |
| + Phase 3B | **+90–120 min** | **~3–3.5 hours** total |
| + Phase 3C | **+4–6 hours** | **~7–9 hours** single shard |

### 9.3 CI sharding requirements

| Phase | Recommendation |
|-------|----------------|
| **3A** | Add 1 macOS job: `phase2-patrol-e2e` (6 tests); keep existing Phase 1 job |
| **3B** | **3 parallel shards** by domain: `(admissions, sis, finance)`, `(hr, inventory, transport)`, `(mobile personas)` — ~70 min wall time |
| **3C** | **4–6 shards** + nightly only; PR gate runs 3A subset (~45 min wall) |

GitHub Actions: each macOS emulator job needs **~14 min** startup overhead beyond test time.

### 9.4 Effort estimate (engineering)

| Phase | Deliverables | Dev-days | QA-days | Total |
|-------|--------------|--------:|--------:|------:|
| **3A** | 12 Patrol files, keys for Phase 2, 6 CRUD deny tests | 3 | 2 | **5** |
| **3B** | 35 journeys, finance/admissions dialog keys, provider tests | 8 | 4 | **12** |
| **3C** | Key inventory script, 120+ journeys, 4-shard CI, docs | 18 | 10 | **28** |
| **Full 3A+3B+3C** | True button-level ERP coverage | 29 | 16 | **~45 dev-days** |

*Assumes mock pilot; live API contract tests add **+30–40%** effort.*

---

## 10. Proposed phases (decision options)

### Phase 3A — Highest-value missing coverage (recommended if QA is prioritized)

**Goal:** Close Phase 2 device gap + secure completion-program workflows on emulator.

| # | Journey | Rationale |
|---|---------|-----------|
| 1 | HR payroll export PDF | Phase 2 widget only |
| 2 | Inventory report export PDF | Phase 2 widget only |
| 3 | Transport report export PDF | Phase 2 widget only |
| 4 | Education report card export | Phase 2 widget only |
| 5 | Inventory PO receive handoff | Finance bridge; widget only |
| 6 | Finance reconciliation receive goods | `inventory_finance` mutation |
| 7 | HR payroll deny path (RBAC) | Security regression |
| 8 | Inventory lifecycle deny path | Security regression |
| 9 | Transport activate deny path | Security regression |
| 10 | Education publish deny path | Security regression |
| 11 | Inventory copilot + lifecycle nav assert | v18.6 inventory gap (81.8%) |
| 12 | Finance report export tap | Key exists; not asserted |

**Outcome:** Phase 1 + 2 fully mirrored on device; **~12 new Patrol files**; CI **+35 min** (one extra job).

---

### Phase 3B — Medium-value coverage

**Goal:** Cover all `*_workflow_actions.dart` dialogs and Finance/Admissions CRUD mutations.

- Add QA keys for **~25 unkeyed manage buttons**
- Patrol per workflow dialog (fee structure, refunds, scholarships, admissions lead ops)
- Provider deny tests for every `assertManage*` mutation (**~35 ops**)
- Mobile: parent payment, teacher homework/marks E2E

**Outcome:** **~77 Patrol suites**; CRUD Class D drops from 35 → **~10**; CI **3 shards ~70 min wall**.

---

### Phase 3C — Exhaustive every-button coverage

**Goal:** App-wide inventory-driven testing.

1. Script: scan `lib/features/**` for `onPressed`, `FilledButton`, `AksharaManageAction` → generate key backlog
2. One Patrol journey per ERP screen (open route → sub-nav tabs → tap keyed actions → back)
3. Widget test per screen (render + no overflow) — **184 tests**
4. Golden tests for mobile dashboards (optional)

**Outcome:** **200+ Patrol suites**; true button coverage; **nightly 4–6 shard pipeline (~2 hr wall)**; **~28 dev-days** beyond 3B.

---

## 11. Decision matrix

| Priority | Choose | Defer |
|----------|--------|-------|
| **Ship ERP features (Exam module, API wiring, Phase 3 product)** | Phase **3A only** on RC branches; rely on `flutter test` for regressions | 3B, 3C |
| **Balance** | **3A + 3B** over 2 releases; shard Patrol on `main` nightly | 3C |
| **Compliance / UAT “every button”** | Full **3C** before production sign-off | New features frozen 4–6 weeks |
| **Speed of CI** | Keep PR gate = `run_ci_gates.sh` only; Patrol nightly | Full Patrol on every PR |

### Recommendation (planning view)

1. **Do not block feature work on 3C** — cost (~45 dev-days) exceeds Phase 3 product scope in `docs/ERP_FINAL_COMPLETION_PLAN.md`.
2. **Do Phase 3A** (~5 days) before next RC — closes honest gap between widget tests and device tests.
3. Revisit **3B vs Exam ERP module** at milestone review: mutations without UI are Class D regardless of QA.

---

## 12. Related documents

- `docs/QA/FINAL_COMPLETION_TEST_AUDIT.md` — Phase 1/2 honest audit
- `docs/ERP_FINAL_COMPLETION_PLAN.md` — Product Phase 3 (audit pattern, journey providers)
- `qa/reports/module_coverage_v18_6.json` — Workflow-name proxy metrics (not button-level)
- `scripts/qa/run_ci_gates.sh` — PR gate (no emulator)
- `qa/patrol/run_erp_coverage.sh` — Full Patrol orchestration

---

## Appendix A — Uncovered item checklist (for tracking)

| Category | Total | Covered (A+B) | Uncovered (C+D) |
|----------|------:|--------------:|------------------:|
| QaTestKeys | 79 | 76 | 3 |
| CRUD operations | 55 | 17 | 38 |
| Workflow dialogs | 25 | 12 | 13 |
| Export actions | 5 | 0 (Patrol) | 5 on device |
| Manage CTAs (estimated unique) | ~40 | ~12 | ~28 |
| Screens (widget test file) | 184 | ~20 modules partial | ~164 screens |

*Last generated from codebase snapshot June 2026 — regenerate before Phase 3 implementation using `scripts/qa/generate_module_coverage_report.py` + key scanner (to be built in 3C).*
