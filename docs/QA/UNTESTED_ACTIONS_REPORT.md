# Untested Actions Report (Post M13)

**Generated:** 2026-06-15 20:06 UTC

## Classification

| Class | Definition |
|-------|------------|
| **A** | Patrol E2E on device |
| **B** | Widget / integration test only |
| **C** | Patrol navigation smoke only |
| **D** | No automated coverage |

## Gap summary

| Area | Total | A | B | D |
|------|------:|--:|--:|--:|
| QaTestKeys | 485 | 150 | 61 | 274 |
| Routes | 255 | 53 | — | 205 |
| Screens | 252 | ~89 suites | ~35 widget files | ~217 |
| Button instances (scan) | 111 | partial | partial | majority |

---

## Priority A — Critical business (untested keys)

- **admissionsApproveButton** (Admissions) — button
- **admissionsCreateApplicationButton** (Admissions) — button
- **admissionsLeadDialogCreateButton** (Admissions) — button
- **enrollmentContinueButton** (Admissions) — button
- **financeCancelCollectionButton** (Finance) — button
- **financeCancelCollectionConfirmButton** (Finance) — button
- **financeCancelInvoiceButton** (Finance) — button
- **financeCancelInvoiceConfirmButton** (Finance) — button
- **financeCollectionSubmitButton** (Finance) — button
- **financeIssueInvoiceButton** (Finance) — button
- **financeQrPayButton** (Finance) — button
- **financeRecordCollectionButton** (Finance) — button
- **hrActivateEmployeeButton** (HR) — button
- **hrApproveLeaveButton** (HR) — button
- **hrEditEmployeeDialogSubmitButton** (HR) — button
- **hrRejectLeaveButton** (HR) — button
- **inventoryDistributionRequestReplacementButton** (Inventory) — button
- **inventoryPoApproveHandoffButton** (Inventory) — button
- **inventoryPoApproveHandoffDialogButton** (Inventory) — button
- **inventoryReplacementFulfillButton** (Inventory) — button
- **inventoryReplacementRejectButton** (Inventory) — button
- **managementApproveButton** (Management) — button
- **managementDashboardPrintButton** (Management) — button
- **managementDashboardShareButton** (Management) — button
- **managementRejectButton** (Management) — button
- **managementSettingsAcademicYearEditButton** (Management) — button
- **sisContinuityExecuteButton** (SIS) — button
- **sisContinuityPreviewButton** (SIS) — button
- **sisPerformanceExecuteButton** (SIS) — button
- **sisPromotionContinueButton** (SIS) — button
- **sisQuarterlyExecuteButton** (SIS) — button
- **sisReshuffleExecuteButton** (SIS) — button
- **sisSectionBalanceExecuteButton** (SIS) — button

## Priority B — Director / Multi-School / Intelligence

- **directorDashboardScreen** (Director)
- **directorCopilotLinkButton** (Director)
- **directorComplianceAcknowledgedSnackbar** (Director)
- **organizationBuilderProvisioningScreen** (Trust Intelligence)
- **organizationBuilderInterviewBackButton** (Trust Intelligence)
- **organizationBuilderInterviewModulesField** (Trust Intelligence)
- **organizationBuilderInterviewWorkflowsField** (Trust Intelligence)
- **organizationBuilderInterviewChannelsField** (Trust Intelligence)
- **organizationBuilderInterviewPaymentsField** (Trust Intelligence)
- **organizationBuilderStartProvisioningButton** (Trust Intelligence)
- **organizationBuilderProvisioningCompleted** (Trust Intelligence)
- **platformOperationsDirectorPortalLink** (Director)
- **directorComplianceAcknowledgeButton** (Director)
- **organizationBuilderPackCard** (Trust Intelligence)
- **organizationBuilderDraftRow** (Trust Intelligence)
- **organizationBuilderRecommendation** (Trust Intelligence)
- **organizationBuilderPreviewModule** (Trust Intelligence)
- **organizationBuilderPreviewRole** (Trust Intelligence)
- **organizationBuilderPreviewWidget** (Trust Intelligence)
- **organizationBuilderPreviewWorkflow** (Trust Intelligence)
- **organizationBuilderProvisioningStep** (Trust Intelligence)

## Priority C — Filters & exports

- **substituteDayFilter** (Shared)
- **substituteClassFilter** (Shared)

## Untested routes (sample — full list in baseline)

- `/` (Other)
- `/splash` (Auth)
- `/login` (Auth)
- `/qa-login` (Auth)
- `/otp` (Other)
- `/staff/login` (Auth)
- `/staff/otp` (Other)
- `/parent` (Parent)
- `/parent/dashboard` (Parent)
- `/parent/attendance` (Parent)
- `/parent/timetable` (Parent)
- `/parent/homework` (Parent)
- `/parent/exams` (Parent)
- `/parent/notices` (Parent)
- `/parent/events` (Parent)
- `/parent/fees` (Parent)
- `/parent/payment` (Parent)
- `/parent/receipts` (Parent)
- `/parent/leave` (Parent)
- `/parent/messages` (Parent)
- `/parent/notifications` (Parent)
- `/teacher` (Teacher)
- `/teacher/attendance` (Teacher)
- `/teacher/timetable` (Teacher)
- `/teacher/homework` (Teacher)
- `/teacher/exams` (Teacher)
- `/teacher/messages` (Teacher)
- `/teacher/leave` (Teacher)
- `/student` (Student)
- `/student/dashboard` (Student)
- `/student/attendance` (Student)
- `/student/timetable` (Student)
- `/student/homework` (Student)
- `/student/exams` (Student)
- `/student/notices` (Student)
- `/student/profile` (Student)
- `/admin` (Admin)
- `/copilot` (Copilot)
- `/settings/ai-assistant` (Copilot/AI)
- `/intelligence` (Intelligence)
- `/intelligence/exam` (Intelligence)
- `/homework-intelligence` (Other)
- `/student-360` (Student)
- `/employees` (HR)
- `/parent/experience` (Parent)
- `/parent/academic-report` (Parent)
- `/employees/360` (HR)
- `/promotions` (Other)
- `/setup-wizard` (Other)
- `/dashboard/dynamic` (Dynamic Widgets)
- `/dynamic-widgets/runtime` (Dynamic Widgets)
- `/teacher-assistant` (Teacher)
- `/parent/insights` (Parent)
- `/principal-command` (Evolution)
- `/school/completion` (School Completion)
- `/school/subjects` (School Completion)
- `/school/lesson-logs` (School Completion)
- `/school/timetables/automate` (School Completion)
- `/school/branding` (School Completion)
- `/school/whatsapp-provider` (School Completion)
- … and 145 more

## Business impact ranking

1. **Finance exports & filters** — reconciliation, defaulters, offline payments
2. **Admissions CRUD** — lead edit, document upload, settings toggles
3. **Management actions** — task assign, performance drill, settings
4. **Director portal navigation** — all sub-screens beyond reports
5. **Industry vertical packs** — navigation depth beyond smoke
6. **AI generation variants** — summarize, recommend per module
7. **Hostel/Library secondary screens** — visitors, fines, digital resources
