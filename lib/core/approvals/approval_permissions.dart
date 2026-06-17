import '../security/permissions.dart';
import 'approval_request_type.dart';

/// Maps approval types to RBAC approve/manage permissions (M-D2 guards).
Permission approvalPermissionForType(ApprovalRequestType type) =>
    switch (type) {
      ApprovalRequestType.admission => Permission.approveAdmissions,
      ApprovalRequestType.refund => Permission.approveRefunds,
      ApprovalRequestType.feeConcession ||
      ApprovalRequestType.feeStructure ||
      ApprovalRequestType.budget ||
      ApprovalRequestType.expense ||
      ApprovalRequestType.payroll ||
      ApprovalRequestType.vendor ||
      ApprovalRequestType.marketing =>
        Permission.manageFinance,
      ApprovalRequestType.inventoryPo => Permission.manageInventory,
      ApprovalRequestType.examResults ||
      ApprovalRequestType.attendanceCorrection ||
      ApprovalRequestType.studentLeave ||
      ApprovalRequestType.staffLeave =>
        Permission.manageManagement,
    };
