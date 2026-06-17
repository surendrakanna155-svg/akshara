import 'approval_request_type.dart';

/// Principal Approval Center filter chips (Phase D M-D2).
enum ApprovalCategory {
  all,
  academic,
  attendance,
  leave,
  finance,
  inventory;

  String get label => switch (this) {
        ApprovalCategory.all => 'All',
        ApprovalCategory.academic => 'Academic',
        ApprovalCategory.attendance => 'Attendance',
        ApprovalCategory.leave => 'Leave',
        ApprovalCategory.finance => 'Finance',
        ApprovalCategory.inventory => 'Inventory',
      };

  bool matchesType(ApprovalRequestType type) => switch (this) {
        ApprovalCategory.all => true,
        ApprovalCategory.academic =>
          type == ApprovalRequestType.examResults,
        ApprovalCategory.attendance =>
          type == ApprovalRequestType.attendanceCorrection,
        ApprovalCategory.leave =>
          type == ApprovalRequestType.studentLeave ||
          type == ApprovalRequestType.staffLeave,
        ApprovalCategory.finance =>
          type == ApprovalRequestType.feeConcession ||
          type == ApprovalRequestType.feeStructure ||
          type == ApprovalRequestType.refund ||
          type == ApprovalRequestType.budget ||
          type == ApprovalRequestType.expense ||
          type == ApprovalRequestType.payroll ||
          type == ApprovalRequestType.vendor ||
          type == ApprovalRequestType.marketing ||
          type == ApprovalRequestType.admission,
        ApprovalCategory.inventory => type == ApprovalRequestType.inventoryPo,
      };
}
