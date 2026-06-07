# Permission Coverage Inventory

**Version:** 1.0 · **Release:** v4.5

## Provider-Level Mutations (Enforced)

| Module | Mutation | Permission | Provider |
|--------|----------|------------|----------|
| Admissions | createLead | manageAdmissions | CreateLeadNotifier |
| Admissions | updateLead | manageAdmissions | UpdateLeadNotifier |
| Admissions | approveApplication | approveAdmissions | ApproveApplicationNotifier |
| Admissions | rejectApplication | approveAdmissions | RejectApplicationNotifier |
| Finance | createFeeStructure | manageFinance | CreateFeeStructureNotifier |
| Finance | approveRefund | **approveRefunds** | ApproveRefundNotifier |
| Finance | createScholarship | manageFinance | CreateScholarshipNotifier |
| SIS | registerStudent | manageSis | RegisterStudentNotifier |
| SIS | assignAcademic | manageSis | AssignAcademicNotifier |

## UI-Level Guards (v4.5)

| Screen | Action | Widget |
|--------|--------|--------|
| Admissions leads | New Lead | AksharaManageAction |
| Admissions enrollment | Submit | AksharaManageAction |
| Admissions fee handoff | Send to Finance | AksharaManageAction |
| Finance refunds | Approve | AksharaApproveAction |
| SIS academic assignment | Save assignment | AksharaManageAction |

## Remaining (Future v4.6+)

- Admissions approval panel buttons (view-only without auth in widget tests)
- Finance fee structures / discounts create buttons
- ERP modules without write APIs (Transport, HR, etc.)
