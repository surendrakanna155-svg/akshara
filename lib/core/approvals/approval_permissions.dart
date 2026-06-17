import '../security/permissions.dart';
import 'approval_request_type.dart';

/// Maps approval types to RBAC approve/manage permissions (M-D2 guards).
Permission approvalPermissionForType(ApprovalRequestType type) =>
    switch (type) {
      ApprovalRequestType.admission => Permission.approveAdmissions,
      ApprovalRequestType.refund => Permission.approveRefunds,
      ApprovalRequestType.feeConcession => Permission.approveFeeConcession,
      ApprovalRequestType.feeStructure => Permission.approveFeeStructure,
      ApprovalRequestType.budget ||
      ApprovalRequestType.expense ||
      ApprovalRequestType.payroll ||
      ApprovalRequestType.vendor ||
      ApprovalRequestType.marketing =>
        Permission.manageFinance,
      ApprovalRequestType.inventoryPo => Permission.approvePurchaseOrder,
      ApprovalRequestType.examResults => Permission.approveExamResults,
      ApprovalRequestType.attendanceCorrection =>
        Permission.approveAttendanceCorrection,
      ApprovalRequestType.studentLeave => Permission.approveStudentLeave,
      ApprovalRequestType.staffLeave => Permission.approveStaffLeave,
    };
