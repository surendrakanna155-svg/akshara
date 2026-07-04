# RBAC Mutation Registry Sync Report

**Program:** Batch A — P1-07  
**Date:** June 2026  
**Baseline commit:** `37c1676`  
**Scope:** Audit all mutation providers, workflow actions, and write operations against `MutationPermissionRegistry`

---

## Executive summary

| Metric | Before Batch A | After Batch A |
|--------|----------------|---------------|
| Registry entries | 28 | **41** |
| Modules with ≥1 registry entry | 9 | **11** |
| Batch A mutations registered | 0 | **13** |
| Deny-path unit tests (Batch A) | 0 | **6** (permission coverage) + HR write RBAC |
| Patrol RBAC journeys | partial | inventory, admissions settings, broadcast, HR leave, receipt PDF |

**Verdict:** Batch A write paths are guarded and registered. Pre-existing gaps remain for secondary admissions/finance/SIS mutations and persona-scoped mobile writes (documented below as **P2 registry backlog**).

---

## Batch A registry additions

| Module | Mutation ID | Permission | Kind | Provider |
|--------|-------------|------------|------|----------|
| admissions | `updateSettings` | `manageAdmissions` | manage | `UpdateAdmissionsSettingsNotifier` |
| communication | `sendBroadcast` | `manageCommunication` | manage | `SendBroadcastNotifier` |
| communication | `saveTemplate` | `manageCommunicationTemplates` | manage | `SaveTemplateNotifier` |
| inventory | `createProcurementOrder` | `manageInventory` | manage | `CreateProcurementOrderNotifier` |
| inventory | `approveProcurementHandoff` | `manageInventory` | manage | `ApproveProcurementHandoffNotifier` |
| inventory | `receiveProcurementHandoff` | `manageInventory` | manage | `ReceiveProcurementHandoffNotifier` |
| hr | `approveLeaveRequest` | `manageHr` | manage | `ApproveHrLeaveNotifier` |
| hr | `rejectLeaveRequest` | `manageHr` | manage | `RejectHrLeaveNotifier` |
| finance | `exportReceiptPdf` | `manageFinance` | manage | `ExportReceiptPdfNotifier` |

---

## Mutation provider audit

### Fully registered modules (Batch A + prior)

| Module | Provider file | Guard pattern | Registry coverage |
|--------|---------------|---------------|-------------------|
| admissions | `admissions_mutations_provider.dart` | `assertManageAdmissions` / `assertApproveAdmissions` | Core + settings ✅ |
| communication | `communication_mutations_provider.dart` | `_assertManageCommunication` / `_assertManageCommunicationTemplates` | Broadcast + template ✅ |
| inventory | `inventory_mutations_provider.dart` | `assertManageInventory` | Procurement chain ✅ |
| hr | `hr_mutations_provider.dart` | `assertManageHr` / `assertApproveHrLeave` | CRUD + leave ✅ |
| finance | `finance_mutations_provider.dart` | `assertManageFinance` / `assertApproveRefunds` | Core + receipt export ✅ |
| sis | `sis_mutations_provider.dart` | `assertManageSis` | Year transition + register ✅ |
| sis/academic_ops | `academic_operations_mutations_provider.dart` | `assertManageSis` | Promotion/reshuffle ✅ |
| continuity | `continuity_mutations_provider.dart` | `assertManageSis` / `assertManageCommunication` | Migration ✅ |
| management | `management_mutations_provider.dart` | `assertManageManagement` | Approvals ✅ |
| workflow | `workflow_automation_mutations_provider.dart` | `assertManageWorkflowAutomation` | Execute ✅ |
| library | `library_mutations_provider.dart` | `assertManageLibrary` | Issue/return ✅ |
| hostel | `hostel_mutations_provider.dart` | `assertManageHostel` | Admit/assign/checkout ✅ |
| transport | `transport_mutations_provider.dart` | `assertManageTransport` | Assign/transfer/remove ✅ |

### Guarded but not in registry (P2 backlog)

These providers enforce RBAC at runtime but are not yet listed in `MutationPermissionRegistry` (pre-existing; not Batch A scope):

| Module | Mutations | Guard | Notes |
|--------|-----------|-------|-------|
| admissions | assignCounselor, changeLeadStage, addLeadFollowUp, addLeadNote, submitApplication, createApplication, submitEnrollment, approveDocument, rejectDocument, sendToFinance | manage/approve | Lead pipeline writes |
| finance | updateFeeStructure, createStudentAccount, assignFeePlan, createCollection, createRefund, rejectRefund, updateScholarship, updateFinanceSettings, issueInvoice, cancelInvoice, cancelCollection | manage/approve | Billing chain |
| sis | createStudent, updateStudent, updateStudentStatus, convertAdmissionsEnrollment | manageSis | Profile CRUD |
| transport | createTransportRoute, activateTransportRoute | manageTransport | Route admin |
| inventory | recordAssetLifecycleEvent | manageInventory | Lifecycle event |
| inventory_finance | approvePurchaseOrder, receiveGoods | finance/inventory handoff | Called via handoff notifiers |
| hr | createHrLeave, processHrPayrollRun | manageHr | Self-service + payroll |
| academic_ops | executeOperationPlan (reshuffle) | manageSis | Covered by executeReshufflePlan entry |

### Persona-scoped writes (intentionally excluded)

Mobile persona mutations use role-scoped guards, not ERP manage permissions:

| Module | File | Scope |
|--------|------|-------|
| parent | `parent_mutations_provider.dart` | Parent session |
| student | `student_mutations_provider.dart` | Student session |
| teacher | `teacher_mutations_provider.dart` | Teacher session |

---

## Workflow actions audit

| File | Actions | RBAC |
|------|---------|------|
| `inventory_workflow_actions.dart` | Approve PO, Receive goods | `canManageInventoryProvider` + mutation providers |
| `admissions_workflow_actions.dart` | Approve/reject application | `canApproveAdmissionsProvider` |
| `finance_workflow_actions.dart` | Refund approve/reject | `canApproveRefundsProvider` |
| `management_workflow_actions.dart` | Resolve approval | `canManageManagementProvider` |
| `hr_workflow_actions.dart` | Employee status | `canManageHrProvider` |
| `hostel_workflow_actions.dart` | Admit/checkout | `canManageHostelProvider` |
| `library_workflow_actions.dart` | Issue/return | `canManageLibraryProvider` |
| `transport_workflow_actions.dart` | Activate route | `canManageTransportProvider` |

All workflow action buttons gate on `canManage*` / `canApprove*` providers before invoking mutation notifiers.

---

## Deny-path test coverage

| Test file | Coverage |
|-----------|----------|
| `test/security/rbac/denied_mutation_test.dart` | Generic `assertManagePermission` / `assertApprovePermission` |
| `test/security/rbac/permission_coverage_test.dart` | Registry completeness + Batch A entry assertions |
| `test/features/hr/hr_write_tests.dart` | Leave approve/reject RBAC deny + pass |
| `test/features/inventory/inventory_write_tests.dart` | Procurement approve/receive chain + RBAC |
| `test/contracts/admissions/admissions_write_contract_test.dart` | Settings write contract |

---

## Permission mapping verification

| Permission | Batch A consumers |
|------------|-------------------|
| `manageAdmissions` | updateSettings |
| `manageCommunication` | sendBroadcast |
| `manageCommunicationTemplates` | saveTemplate (new `canManageCommunicationTemplatesProvider`) |
| `manageInventory` | createProcurementOrder, approveProcurementHandoff, receiveProcurementHandoff |
| `manageHr` | approveLeaveRequest, rejectLeaveRequest |
| `manageFinance` | exportReceiptPdf |

Route guards updated for `/school/communications/broadcast-admin` → `manageCommunication`.

---

## Recommendations (post Batch A)

1. **P2 registry expansion:** Add remaining admissions/finance/SIS mutation IDs to registry (28 additional entries estimated).
2. **Dedicated approve permission:** Consider `approveHrLeave` permission enum separate from `manageHr` for manager-only workflows.
3. **Inventory-finance handoff:** Register `inventoryFinanceApprovePurchaseOrder` as alias under inventory module for cross-repo traceability.
4. **Automated drift check:** Add CI script comparing `@riverpod` mutation notifiers to registry entries.

---

## Related files

- `lib/core/security/mutation_permission_registry.dart`
- `lib/core/security/mutation_permission_validator.dart`
- `test/security/rbac/permission_coverage_test.dart`
- `test/security/rbac/denied_mutation_test.dart`
