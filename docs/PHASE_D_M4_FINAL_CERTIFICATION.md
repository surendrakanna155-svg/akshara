# Phase D M-D4 — Final Certification

**Milestone:** M-D4 — Leave & Attendance Approval Adapters  
**Branch:** `feature/m15-theme`  
**Certification date:** 2026-06-17  
**Verdict:** ✅ **PASS**

---

## Validation checklist

| # | Requirement | Result |
|---|-------------|--------|
| 1 | Parent leave submit → `studentLeave` pending item | ✅ |
| 2 | Principal approve updates parent leave status | ✅ |
| 3 | HR staff leave submit → `staffLeave` pending item | ✅ |
| 4 | Principal reject stores comment in governance store | ✅ |
| 5 | `AttendanceCorrectionApprovalAdapter` registered (stub) | ✅ |
| 6 | RBAC: `approveStudentLeave`, `approveStaffLeave`, `submit*` | ✅ |
| 7 | `LEAVE_AUTO_APPROVE` rollback flag | ✅ |
| 8 | `flutter test` governance suites green | ✅ |

## Test evidence

- `test/integration/approval/attendance_governance_integration_test.dart` (2 tests)
- `test/features/management/approval/approval_center_provider_test.dart` (leave filters + permissions)
- Full suite: **1904 passed**, 1 skipped

## Key files

- `lib/core/approvals/adapters/student_leave_approval_adapter.dart`
- `lib/core/approvals/adapters/staff_leave_approval_adapter.dart`
- `lib/core/approvals/adapters/attendance_correction_approval_adapter.dart`
- `lib/core/leave/student_leave_governance_store.dart`
- `lib/core/leave/staff_leave_governance_store.dart`
- `lib/features/parent/parent_mutations_provider.dart`
- `lib/features/hr/hr_mutations_provider.dart`
