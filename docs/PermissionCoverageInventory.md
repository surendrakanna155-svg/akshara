# Permission Coverage Inventory

**Version:** 2.0 · **Release:** v5.3

## Provider-Level Mutations (Enforced)

| Module | Mutation | Permission | Provider |
|--------|----------|------------|----------|
| Admissions | createLead | manageAdmissions | CreateLeadNotifier |
| Admissions | updateLead | manageAdmissions | UpdateLeadNotifier |
| Admissions | approveApplication | approveAdmissions | ApproveApplicationNotifier |
| Admissions | rejectApplication | approveAdmissions | RejectApplicationNotifier |
| Finance | createFeeStructure | manageFinance | CreateFeeStructureNotifier |
| Finance | approveRefund | approveRefunds | ApproveRefundNotifier |
| Finance | createScholarship | manageFinance | CreateScholarshipNotifier |
| SIS | registerStudent | manageSis | RegisterStudentNotifier |
| SIS | assignAcademic | manageSis | AssignAcademicNotifier |

## UI-Level Guards (v5.3 Complete)

| Module | Screen | Action | Widget | Permission |
|--------|--------|--------|--------|------------|
| Admissions | Leads | New Lead | AksharaManageAction | manageAdmissions |
| Admissions | Lead detail | Add note / follow-up / stage | AksharaManageAction | manageAdmissions |
| Admissions | Applications | New Application | AksharaManageAction | manageAdmissions |
| Admissions | Approval | Approve / Reject | AksharaApproveAction | approveAdmissions |
| Admissions | Documents | Approve / Reject | AksharaApproveAction | approveAdmissions |
| Admissions | Enrollment | Submit | AksharaManageAction | manageAdmissions |
| Admissions | Fee handoff | Send to Finance | AksharaManageAction | manageAdmissions |
| Finance | Fee structures | Create | AksharaManageAction | manageFinance |
| Finance | Discounts | Add scholarship | AksharaManageAction | manageFinance |
| Finance | Fee assignment | Generate account | AksharaManageAction | manageFinance |
| Finance | Refunds | Approve / Reject | AksharaApproveAction | approveRefunds |
| SIS | Academic assignment | Save | AksharaManageAction | manageSis |
| SIS | Admissions conversion | Convert student | AksharaManageAction | manageSis |
| Library | 7 screens | Create/issue actions | AksharaManageAction | manageLibrary |
| Alumni | 6 screens | Create/campaign actions | AksharaManageAction | manageAlumni |
| Control Center | 4 screens | Add/configure actions | AksharaManageAction | manageControlCenter |
| Transport | 3 screens | Add route/allocation | AksharaManageAction | manageTransport |
| Inventory | 3 screens | Add procurement/allocation | AksharaManageAction | manageInventory |
| Hostel | 4 screens | Add student/room/visitor | AksharaManageAction | manageHostel |
| HR | Dashboard | Export | AksharaManageAction | manageHr |
| Management | Dashboard | Export | AksharaManageAction | manageManagement |

**Total UI guards:** 49 actions across 44 screens

## Remaining (Backend)

- Server-side RBAC enforcement (TD-P0-01)
- Server-side permission sync validation in production
