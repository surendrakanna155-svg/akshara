# Journey Implementation Readiness — Akshara ERP v18.7

**Date:** 13 June 2026  
**Baseline:** v18.6.2-final-suite-recovery (`18.6.2+187`)  
**References:** [`coverage_audit_v18.7.md`](coverage_audit_v18.7.md), [`e2e_journey_gap_analysis.md`](e2e_journey_gap_analysis.md)  
**Method:** Architecture review of providers, repositories, UI, mutation flows, mock business logic, and Patrol coverage — **no code changes**

---

## Executive Summary

The QA bottleneck is **not test infrastructure**. Patrol helpers, QA login personas, mock repositories, and mutation providers exist for most P0 steps. The blockers are:

1. **Incomplete transaction chains** — mock store does not always propagate state across steps (admissions stages, teacher→parent attendance).
2. **Missing UI for repository-ready writes** — finance fee collection (`createCollection`) and report export buttons are the clearest examples.
3. **Missing provider wiring** — repository interfaces expose methods with no corresponding `AsyncNotifier` or workflow action.
4. **QA hook sparsity** — only `enrollmentContinueButton` and sub-nav keys exist; form/dialog actions rely on text labels.

### Readiness classification key

| Class | Meaning |
|-------|---------|
| **A** | Ready for E2E automation now |
| **B** | Requires QA hooks only |
| **C** | Requires missing UI implementation |
| **D** | Requires missing business logic |
| **E** | Requires product design decisions |

### Journey verdict at a glance

| Journey | Overall class | Blocker type | Can automate any write today? |
|---------|---------------|--------------|-------------------------------|
| **1. Admission → SIS** | **B** (+ **D** for strict chain) | QA hooks; mock stage linking | **Yes** — every step has UI + mutation |
| **2. Fee** | **C** | Missing collection UI + provider | **Partial** — assignment only |
| **3. Attendance** | **A/B** (teacher) · **D** (parent chain) | Parent mock is static | **Yes** — teacher submit (Patrol proven) |

---

## Cross-Cutting Architecture

### Repository layer (Agent A ownership)

| Module | Interface | Mock write methods | API remote | Contract tests |
|--------|-----------|-------------------|------------|----------------|
| Admissions | `AdmissionsRepository` | 17 write methods | ✅ | `admissions_write_contract_test.dart` |
| Finance | `FinanceRepository` | 15+ write methods incl. `createCollection`, `issueInvoice` | ✅ | `finance_write_contract_test.dart` |
| SIS | `SisRepository` | `createStudent`, `convertAdmissionsEnrollment`, … | ✅ | `sis_write_contract_test.dart` |
| Teacher | `TeacherRepository` | `saveAttendanceDraft`, `submitClassAttendance` | ✅ | teacher contracts |
| Parent | `ParentRepository` | Read-heavy; leave submit only | ✅ | parent contracts |

### Feature mutation providers

| Module | Provider file | Write providers |
|--------|---------------|-----------------|
| Admissions | `admissions_mutations_provider.dart` | 14 (`createLead` … `sendToFinance`) |
| Finance | `finance_mutations_provider.dart` | 11 — **no `createCollectionProvider`** |
| SIS | `sis_mutations_provider.dart` | 5 incl. `convertAdmissionsEnrollmentProvider` |
| Teacher | `teacher_mutations_provider.dart` | `saveTeacherAttendanceDraftProvider`, `submitTeacherClassAttendanceProvider` |

### QA infrastructure

| Asset | Status |
|-------|--------|
| `QaTestKeys` | Minimal — login, drawer, sub-nav, `enrollmentContinueButton`, `inventoryLifecycleScreen`, `receiptHistoryButton` |
| Patrol helpers | Mature — `navigateErpWorkflow`, `goToErpRoute`, `tapEnrollmentContinue`, `scrollTap` |
| Patrol write proof | Teacher attendance submit only |
| Maestro | 118 YAML files — navigation smoke; not CI-gated |

### Blocker taxonomy (this review)

| Layer | Example |
|-------|---------|
| **Testing** | Not the primary blocker — 147 Patrol workflows exist |
| **UI** | Finance collection screen read-only; report export `onPressed: () {}` |
| **Backend/provider** | `FinanceRepository.createCollection` with no mutation provider |
| **Business logic** | Mock admissions stages don't auto-link; teacher submit doesn't update parent attendance |
| **Product scope** | Whether approval is mandatory before SIS conversion; ERP academic attendance reports |

---

## Journey 1 — Admission → SIS Student Creation

**Path:** Lead → Application → Enrollment → Approval → SIS Student Creation

### Overall readiness: **B** (automate now with QA hooks)

**Caveat:** A *strict* single-record chain that creates a lead and flows it through approval into SIS without using pre-seeded data requires **D** — mock orchestration gaps (see Business logic).

---

### Step-by-step readiness

| Step | Class | Existing stack | Patrol today |
|------|-------|----------------|--------------|
| **Lead** | **B** | Repo `createLead`; `createLeadProvider`; `showCreateLeadDialog`; `AdmissionsLeadsScreen` FAB | Anchor `'New Lead'` only |
| **Application** | **B** | `createApplicationProvider`, `submitApplicationProvider`; inline create + table submit on `AdmissionsApplicationsScreen` | Anchor `'New Application'` |
| **Enrollment** | **B** | 4-step wizard; `submitEnrollmentProvider`; `EnrollmentFormNotifier.submit()`; `QaTestKeys.enrollmentContinueButton` | Steps 1–2 partial; no full submit |
| **Approval** | **B** | `approveAdmissionProvider`; `runApproveAdmission`; `AdmissionsApprovalScreen` | Anchor `'Ananya Reddy'` (pre-seeded) |
| **SIS creation** | **B** | `convertAdmissionsEnrollmentProvider`; `completeSisEnrollmentConversion`; `SisAdmissionsConversionScreen` | Separate tab; anchor only |

---

### Existing providers

**Read / view state**

- `admissionsLeadsFutureProvider`, `admissionsApplicationsFutureProvider`, `admissionsEnrollmentPrefillFutureProvider`, `admissionsApprovalQueueFutureProvider`, `admissionsPendingEnrollmentsFutureProvider`
- `sisAdmissionsConversionFutureProvider`, `sisEnrollmentQueueProvider`, `sisPendingEnrollmentsProvider`, `sisStudentsFutureProvider`

**Write / mutations (admissions)**

```
createLeadProvider, updateLeadProvider, assignCounselorProvider, changeLeadStageProvider,
addLeadFollowUpProvider, addLeadNoteProvider, createApplicationProvider, submitApplicationProvider,
submitEnrollmentProvider, approveDocumentProvider, rejectDocumentProvider,
approveAdmissionProvider, rejectAdmissionProvider, sendToFinanceProvider
```

**Write / mutations (SIS)**

```
createStudentProvider, updateStudentProvider, updateStudentStatusProvider,
assignAcademicAssignmentProvider, convertAdmissionsEnrollmentProvider
```

**Workflow actions**

- `admissions_workflow_actions.dart` — dialogs for lead, counselor, stage, notes, follow-ups; `runApproveAdmission`, `runSendToFinance`
- `sis_admissions_integration_provider.dart` — `completeSisEnrollmentConversion()` with mock override path

**Enrollment UI**

- `AdmissionsEnrollmentScreen` — multi-step form with validation (`enrollment_validation.dart`)
- Submit button: `'Submit enrollment'` → `notifier.submit()` → `submitEnrollmentProvider`

---

### Existing repositories

| Method | Mock | API | Used in UI |
|--------|------|-----|------------|
| `createLead` | ✅ persists to `_store.leads` | ✅ | ✅ dialog |
| `createApplication` / `submitApplication` | ✅ | ✅ | ✅ screen |
| `submitEnrollment` | ✅ inserts `_store.enrollments` | ✅ | ✅ wizard |
| `approveAdmission` | ✅ updates `_store.approvalQueue` | ✅ | ✅ approval panel |
| `convertAdmissionsEnrollment` | ✅ creates `SisStudent` in `_store.students` | ✅ | ✅ conversion screen |

---

### Existing UI screens

| Screen | Route area | Write actions wired |
|--------|------------|---------------------|
| `AdmissionsLeadsScreen` | Leads | Create lead dialog |
| `AdmissionsApplicationsScreen` | Applications | Create + submit draft |
| `AdmissionsEnrollmentScreen` | Enrollment | Wizard continue + submit |
| `AdmissionsApprovalScreen` | Approval | Approve / reject |
| `SisAdmissionsConversionScreen` | SIS → Admissions Conversion | Convert enrollment |
| `SisRegistryScreen` (downstream) | Student Registry | Read — assert new row |

10/10 admissions screens have widget tests; enrollment wizard tested in `admissions_phase2_screens_test.dart`.

---

### Existing mutation flows (end-to-end in app)

```
Leads FAB → showCreateLeadDialog → createLeadProvider → SnackBar "Lead created successfully"

Applications "New Application" → createApplicationProvider → SnackBar "Draft application created"
Table draft row → submitApplicationProvider → "Application submitted"

Enrollment wizard → Continue (×3) → Submit enrollment → submitEnrollmentProvider
  → PendingEnrollmentRecord in mock store

Approval panel → runApproveAdmission → approveAdmissionProvider → "Admission approved"

SIS conversion → completeSisEnrollmentConversion → convertAdmissionsEnrollment
  → student appended to registry; enrollment status → converted
```

---

### Existing Patrol coverage

| File | Workflows | Write? |
|------|-----------|--------|
| `admissions_workflows_test.dart` | 5 — leads, apps, enrollment ×2, approval | No — anchors + 1 Continue tap |
| `erp_workflows_test.dart` | enrollment cross-smoke | No |
| `sis_workflows_test.dart` | `sis admissions conversion` | No |
| `erp_coverage_smoke_test.dart` | enrollment anchor | No |

**Flutter write tests:** `admissions_write_tests.dart` — RBAC deny on `createLead` only; contract tests cover mock persistence.

---

### Missing implementation

| Gap | Layer | Severity |
|-----|-------|----------|
| Fee collection handoff after approval | UI exists (`AdmissionsFeeHandoffScreen`) | Out of scope for this journey; optional step |
| Lead → application linking in UI | UI — `_createApplication` uses hardcoded names, **no `leadId`** | Medium for CRM fidelity |
| Dynamic approval queue from new enrollment | Business logic | Medium for strict chain |

---

### Missing QA hooks

| Hook | Target | Priority |
|------|--------|----------|
| `admissions_create_lead_button` | Leads FAB | P0 |
| `admissions_lead_dialog_create` | Lead dialog confirm | P0 |
| `admissions_create_application_button` | Applications FAB | P0 |
| `admissions_submit_enrollment_button` | Enrollment final step | P0 |
| `admissions_approve_button` | Approval panel | P0 |
| `sis_convert_enrollment_button` | Conversion screen | P0 |
| `sis_registry_student_row` | Registry assert | P0 |
| Success snackbar keys (optional) | Each step | P1 |

Only `QaTestKeys.enrollmentContinueButton` exists today.

---

### Missing business logic

| Gap | Evidence | Impact on E2E |
|-----|----------|---------------|
| **Application submit does not enqueue approval** | `mock_admissions_repository.dart` — `submitApplication` only updates application status | New applications won't appear in AD-07 approval queue |
| **Enrollment submit does not enqueue approval** | `submitEnrollment` inserts enrollment only | Approval and enrollment are **parallel paths** in mock data |
| **Lead not linked to application** | `CreateApplicationRequest` in screen omits `leadId` | Lead → Application is a manual CRM convention, not enforced |
| **SIS conversion queue sources enrollments** | `sisEnrollmentQueueProvider` ← `admissionsPendingEnrollmentsProvider` | **Enrollment → SIS works** for newly submitted enrollments |
| **Conversion queue index** | `convertAdmissionsEnrollment` requires enrollment in `_store.conversionQueue` | Mock pre-seeds queue; new enrollments may need store sync (verify at test time) |

**Practical E2E strategy without mock fixes:**

- **Path A (recommended):** Lead → Application → Enrollment submit → SIS convert → Registry assert *(skips approval or uses pre-seeded approval as read-only smoke)*
- **Path B (strict):** Add mock orchestration: `submitEnrollment` → append approval queue item *(Agent A mock, ~1–2 days)*

---

### Missing product decisions

| Question | Class **E** |
|----------|-------------|
| Is principal approval mandatory before SIS conversion? | Code allows conversion from enrollment queue independently |
| Must lead convert to application before enrollment? | Not enforced in UI |
| Document verification gate before approval? | AD-06 exists but not in P0 path |

---

### Estimated effort

| Work | Owner | Days |
|------|-------|------|
| QA keys (6–8 touchpoints) | B | 1–2 |
| Patrol single E2E chain (Path A) | E | 2–3 |
| Mock orchestration for strict chain (optional) | A | 1–2 |
| RBAC variant (principal approve deny) | D + E | 1 |
| **Total (Path A, recommended)** | | **4–6** |

---

## Journey 2 — Fee

**Path:** Student → Fee Assignment → Fee Collection → Receipt → Ledger/Reports

### Overall readiness: **C** (missing UI blocks collection step)

Assignment is **B**. Full journey cannot reach production validation until collection UI + provider exist.

---

### Step-by-step readiness

| Step | Class | Notes |
|------|-------|-------|
| **Student / handoff context** | **B** | Pre-seeded handoffs + SIS students; cross-module data in `pilot_workflow_certification_test` |
| **Fee assignment** | **B** | `executeAssignFeePlan` + snackbar fully wired |
| **Fee collection (write)** | **C + D** | Repo ✅ · Provider ❌ · UI ❌ |
| **Receipt** | **B** (read) | `getCollectionDetail`, `getReceipt`; collections search icon in Patrol |
| **Ledger / reports** | **C** | Catalog UI ✅; export buttons are **no-ops** |

---

### Existing providers

**Read**

- `financePendingHandoffsProvider`, `financeHandoffQueueProvider`, `financeFeeStructuresFutureProvider`, `financeInstallmentPlansFutureProvider`
- `financeCollectionsFutureProvider`, `financeCollectionDetailFutureProvider`, `financeReportsFutureProvider`

**Write**

```
createFeeStructureProvider, updateFeeStructureProvider, createStudentAccountProvider,
updateStudentAccountProvider, assignFeePlanProvider, createRefundProvider,
approveRefundProvider, rejectRefundProvider, createScholarshipProvider,
updateScholarshipProvider, updateFinanceSettingsProvider
```

**Not implemented**

- `createCollectionProvider` — **does not exist**
- `issueInvoiceProvider` — **does not exist**
- `cancelCollectionProvider` — **does not exist**

**Integration**

- `finance_admissions_handoff_provider.dart` — bridges admissions handoffs to assignment queue
- `completeFinanceHandoffAssignment()` — local state after `assignFeePlan`

---

### Existing repositories

| Method | Mock | API | UI wired |
|--------|------|-----|----------|
| `assignFeePlan` | ✅ | ✅ | ✅ `FinanceFeeAssignmentScreen` |
| `createStudentAccount` | ✅ | ✅ | Via assign flow |
| `createCollection` | ✅ full impl (invoice update, receipt #) | ✅ remote | **❌ none** |
| `issueInvoice` | ✅ | ✅ | **❌ none** |
| `getReceipt` / `getCollectionDetail` | ✅ | ✅ | Read-only detail screen |
| `getReportsData` | ✅ | ✅ | Read catalog |

Mock `createCollection` generates `RCP-YYYY-*` receipt numbers and updates invoice outstanding — **ready for E2E once UI exists**.

---

### Existing UI screens

| Screen | Write capability |
|--------|------------------|
| `FinanceFeeAssignmentScreen` | ✅ Assign plan → snackbar "Fee account created for …" |
| `FinanceCollectionsScreen` | ❌ Read-only payment list |
| `FinanceCollectionDetailScreen` | ❌ Read-only timeline |
| `FinanceStudentAccountsScreen` | ❌ Read + navigate |
| `FinanceReportsScreen` | ❌ Export PDF/Excel/Email → `onPressed: () {}` |
| `FinanceFeeStructuresScreen` | ✅ Create structure dialog |

---

### Existing mutation flows

```
Admissions handoff queue → select handoff → _AssignmentPanel → executeAssignFeePlan
  → assignFeePlanProvider → completeFinanceHandoffAssignment → snackbar

FinanceFeeStructuresScreen → showCreateFeeStructureDialog → createFeeStructureProvider

Collections → (no write path in finance_workflow_actions.dart)

Reports → Export buttons → no-op
```

`finance_workflow_actions.dart` ends at settings/scholarship/refund — **no collect/pay workflow**.

---

### Existing Patrol coverage

| File | Workflows | Write? |
|------|-----------|--------|
| `finance_workflows_test.dart` | 6 — structures, assign, collect anchor, receipt search, reports, defaulters | No |
| `erp_workflows_test.dart` | collections dashboard, reports | No |
| `erp_coverage_smoke_test.dart` | parent Pay Now → `'Pay Fee'` dialog | Partial mobile |

---

### Missing implementation

| Item | Layer | Class |
|------|-------|-------|
| Collection entry UI (dialog or slide-over) | UI | **C** |
| `createCollectionProvider` + RBAC audit | Provider | **D** |
| `executeRecordCollection` in workflow actions | UI | **C** |
| Invoice selection / amount entry | UI | **C** |
| Report export handlers | UI | **C** |
| Post-collection navigation to receipt detail | UI | **C** (minor) |

---

### Missing QA hooks

| Hook | Purpose |
|------|---------|
| `finance_assign_fee_plan_button` | Assignment panel confirm |
| `finance_collect_payment_button` | Open collection dialog |
| `finance_collection_amount_field` | Amount entry |
| `finance_collection_submit_button` | Trigger `createCollection` |
| `finance_collection_success_receipt` | Assert receipt number |
| `QaTestKeys.receiptHistoryButton` | ✅ exists — link after collection |
| `finance_report_export_pdf_button` | After export wired |

---

### Missing business logic

| Gap | Evidence |
|-----|----------|
| Assignment → invoice issuance | `issueInvoice` in repo but no UI chain from assignment to collectible invoice |
| Parent Pay Now → ERP collection | Mobile payment flow separate from ERP `createCollection` |
| Report export | Buttons present; no download/share implementation |
| KPI "Collected today" | Dashboard metric — not tied to new collection without provider invalidation |

---

### Missing product decisions

| Question | Class **E** |
|----------|-------------|
| Collection entry point — Collections tab vs Student Accounts vs Defaulters? | No unified "Collect fee" CTA in ERP UI today |
| Partial vs full payment rules | Mock validates amount ≤ outstanding |
| Receipt delivery — print, email, parent app push? | Out of scope for v18.7 |

---

### Estimated effort

| Work | Owner | Days |
|------|-------|------|
| `createCollectionProvider` + workflow action | B + A | 2–3 |
| Collection UI (dialog + invoice picker) | B | 2–3 |
| QA keys + Patrol assign → collect → receipt | E | 2–3 |
| Report export stub → minimal handler | B | 1–2 |
| **Total** | | **7–11** |

---

## Journey 3 — Attendance

**Path:** Teacher Attendance Entry → Submission → Parent/Academic Summary

### Overall readiness

| Segment | Class |
|---------|-------|
| Teacher entry + submit | **A** (Patrol-proven; optional QA keys → **B**) |
| Parent summary verification | **D** |
| Academic / ERP reports | **E** |

---

### Step-by-step readiness

| Step | Class | Notes |
|------|-------|-------|
| **Teacher entry** | **A/B** | Full UI; mark toggles; `'All present'` text tap in Patrol |
| **Submission** | **A/B** | `submitTeacherClassAttendanceProvider` → success snackbar — **only proven Patrol write** |
| **Parent summary** | **D** | `MockParentRepository.getAttendance` returns **static** `AttendanceMonthData.mock()` |
| **Academic summary / reports** | **E** | No ERP student attendance module; HR staff attendance is a different domain |

---

### Existing providers

**Teacher**

- `teacherAttendanceProvider`, `teacherAttendanceClassProvider`, `teacherAttendanceStudentsFutureProvider`
- `saveTeacherAttendanceDraftProvider`, `submitTeacherClassAttendanceProvider`
- `submitAttendance()` in `teacher_attendance_provider.dart` — orchestrates submit + local state flags

**Parent**

- `parentAttendanceProvider` (via screen providers) — reads `parentRepository.getAttendance(month:)`

**No shared attendance sync provider** between teacher write and parent read.

---

### Existing repositories

| Method | Mock behavior |
|--------|---------------|
| `TeacherRepository.submitClassAttendance` | Updates `_store.attendanceDrafts`, `_store.submittedClasses`; returns counts |
| `TeacherRepository.getAttendanceStudentsByClass` | Static seeded roster incl. `Ravi Kumar` |
| `ParentRepository.getAttendance` | **Always returns hardcoded 94% KPI** — ignores teacher submit |

---

### Existing UI screens

| Screen | Actions |
|--------|---------|
| `TeacherAttendanceScreen` | Mark present/absent/late; Save draft; **Submit** → `'Attendance submitted successfully.'` |
| `ParentAttendanceScreen` | Monthly KPI strip, calendar, logs — read only |
| `StudentDashboardScreen` | Attendance KPI card — read only |
| HR `Staff attendance` | Staff domain — not student academic path |

---

### Existing mutation flows

```
Teacher Classes tab → mark students → Submit
  → submitTeacherClassAttendanceProvider
  → MockTeacherRepository.submitClassAttendance
  → teacherAttendanceSubmittedProvider = true
  → SnackBar success

Parent Attendance tab → getAttendance(month)
  → AttendanceMonthData.mock() — unchanged by teacher submit
```

---

### Existing Patrol coverage

| File | Workflow | Write? |
|------|----------|--------|
| `teacher_workflows_test.dart` | `teacher attendance submit` | **✅ Yes** |
| `erp_coverage_smoke_test.dart` | `smoke: teacher attendance submit` | **✅ Yes** |
| `parent_workflows_test.dart` | `parent attendance` | Read anchor only |
| `student_workflows_test.dart` | `student attendance` | Read anchor only |

This is the **only P0 journey with a production-quality Patrol write test today**.

---

### Missing implementation

| Item | Layer |
|------|-------|
| Shared mock attendance store (teacher write → parent read) | Business logic **D** |
| ERP academic attendance summary screen | Product **E** |
| Attendance report export | Product **E** |

---

### Missing QA hooks

| Hook | Status |
|------|--------|
| `teacher_attendance_all_present_button` | Text `'All present'` used today |
| `teacher_attendance_submit_button` | Text `'Submit'` used today |
| `teacher_attendance_success_message` | Text assert works — key optional |
| `parent_attendance_kpi_percent` | Needed for post-sync assert |

Patrol already passes without keys — keys improve stability only.

---

### Missing business logic

| Gap | Evidence | Class |
|-----|----------|-------|
| Teacher submit does not propagate to parent mock | `mock_parent_repository.dart` line 26–30 — static mock | **D** |
| No cross-persona invalidation | Teacher invalidates teacher providers only | **D** |
| Staging seed claims parent visibility | `Demo-Accounts.md` — API/staging only | N/A for QA mock APK |

**E2E chain teacher → parent cannot validate real data sync in mock mode without mock store work.**

---

### Missing product decisions

| Question | Class **E** |
|----------|-------------|
| Is parent summary same-day or end-of-day aggregated? | Affects assert timing |
| ERP vs mobile ownership of attendance reports | No ERP module today |
| HR staff attendance vs student attendance | Separate Patrol workflows |

---

### Estimated effort

| Work | Owner | Days |
|------|-------|------|
| QA keys (optional stability) | B | 0.5–1 |
| Extend existing Patrol (already done for submit) | E | 0 |
| Mock shared store teacher → parent | A | 2–3 |
| Patrol teacher → logout → parent assert KPI | E | 1–2 |
| ERP academic reports (if in scope) | B + E | 5+ |
| **Total (teacher + parent chain)** | | **4–6** |
| **Total (teacher submit only — already green)** | | **0–1** |

---

## Comparative Readiness Matrix

| Criterion | Admission → SIS | Fee | Attendance |
|-----------|-----------------|-----|------------|
| Repository writes complete | ✅ | ✅ (incl. collect) | ✅ teacher only |
| Mutation providers complete | ✅ | ⚠️ no collect | ✅ teacher |
| UI write flows complete | ✅ all steps | ⚠️ assign only | ✅ teacher |
| Mock chain integrity | ⚠️ stages decoupled | ⚠️ assign→invoice gap | ❌ parent static |
| Patrol write proven | ❌ | ❌ | ✅ |
| Cross-module ERP validation | ✅ Admissions↔SIS | ✅ Admissions↔Finance handoff | ⚠️ mobile only |
| QA hooks needed | Medium | Medium | Low |
| Feature build before E2E | No | **Yes (collection UI)** | Mock sync for parent |
| Production readiness impact | **Highest** — student lifecycle | **High** — revenue | Medium — ops |

---

## Blocker Summary by Layer

| Layer | Admission | Fee | Attendance |
|-------|-----------|-----|------------|
| **Testing** | — | — | — |
| **UI** | — | Collection + export stubs | — |
| **Provider** | — | `createCollectionProvider` | — |
| **Business logic** | Stage linking in mock | Invoice issuance chain | Teacher→parent sync |
| **Product** | Approval vs SIS order | Collection entry UX | ERP reports scope |

---

## Final Recommendation

### Implement and automate next: **Admission Journey (Lead → Application → Enrollment → SIS Student Creation)**

**Readiness class: B** — requires QA hooks and a Patrol E2E spec, not new feature modules.

#### Why this journey maximizes the four criteria

| Criterion | Rationale |
|-----------|-----------|
| **QA confidence** | Validates the only **cross-module ERP write chain** (Admissions + SIS) with 19 combined mutation providers, contract tests, and integration parity tests — far more surface area than attendance alone |
| **Real ERP validation** | Exercises principal workflow, enrollment wizard validation, RBAC (`manageAdmissions`, SIS conversion permissions), and persistent student registry — core school onboarding |
| **Production readiness** | Student record creation is the **prerequisite** for fee assignment, transport allocation, and academic modules; fee collection is blocked on UI anyway |
| **Reuse of existing code** | `showCreateLeadDialog`, application create/submit, enrollment submit, `completeSisEnrollmentConversion` — all wired; only keys + Patrol glue needed |

#### Why not Fee first

- **`createCollection` has no mutation provider and no UI** — Class **C/D** blocker; 7–11 days of feature work before E2E adds value
- Assignment alone is valuable but incomplete journey; audit metric requires write chains

#### Why not Attendance first

- **Patrol write already green** — incremental QA gain is small for teacher submit
- Parent/academic chain requires **mock business logic** (Class **D**) before cross-persona E2E means anything
- Does not validate ERP admin modules or cross-module handoffs

#### Suggested implementation sequence

1. **Week 1:** QA keys on admission + SIS conversion touchpoints (Agent B) — **1–2 days**
2. **Week 1–2:** Single Patrol E2E — Path A: lead → application → enrollment submit → SIS convert → registry assert (Agent E) — **2–3 days**
3. **Week 2 (optional):** Mock orchestration linking enrollment → approval queue for strict chain (Agent A) — **1–2 days**
4. **Week 3+:** Fee collection UI + provider, then Fee E2E building on admission handoff (Agent B → E)

#### Definition of done (Admission E2E)

- [ ] One Patrol test performs writes at ≥4 steps (not navigation-only)
- [ ] Asserts new student in SIS registry by name or admission number
- [ ] Runs green in `qa/patrol/run_erp_coverage.sh` full suite
- [ ] Document mock path used (Path A vs strict Path B)

---

## Appendix — File Reference

| Journey | Key files |
|---------|-----------|
| Admission mutations | `lib/features/admissions/admissions_mutations_provider.dart` |
| Admission workflows | `lib/features/admissions/admissions_workflow_actions.dart` |
| Enrollment wizard | `lib/features/admissions/enrollment/admissions_enrollment_screen.dart` |
| SIS conversion | `lib/features/sis/admissions_conversion/sis_admissions_conversion_screen.dart` |
| SIS integration | `lib/features/sis/integration/sis_admissions_integration_provider.dart` |
| Mock admissions | `lib/core/repositories/mock/mock_admissions_repository.dart` |
| Finance mutations | `lib/features/finance/finance_mutations_provider.dart` |
| Finance assignment | `lib/features/finance/fee_assignment/finance_fee_assignment_screen.dart` |
| Finance collections (read) | `lib/features/finance/collections/finance_collections_screen.dart` |
| Finance reports stubs | `lib/features/finance/reports/finance_reports_screen.dart` (export no-ops) |
| Teacher attendance | `lib/features/teacher/attendance/teacher_attendance_screen.dart` |
| Teacher submit Patrol | `patrol_test/workflows/teacher_workflows_test.dart` |
| Parent attendance mock | `lib/core/repositories/mock/mock_parent_repository.dart` |
| QA keys | `lib/core/testing/qa_test_keys.dart` |
| Cross-module tests | `test/integration/cross_module/cross_module_workflow_integration_test.dart` |

---

*Architecture review only — no implementation performed. Aligns with Agent E (QA) analysis scope; feature gaps hand to Agent B/A per AGENTS.md.*
