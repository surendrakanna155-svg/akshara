/// Cross-module approval categories for the Principal Approval Center.
enum ApprovalRequestType {
  examResults,
  attendanceCorrection,
  studentLeave,
  staffLeave,
  feeConcession,
  feeStructure,
  inventoryPo,
  refund,
  admission,
  budget,
  expense,
  payroll,
  vendor,
  marketing;

  String get label => switch (this) {
        ApprovalRequestType.examResults => 'Exam results',
        ApprovalRequestType.attendanceCorrection => 'Attendance correction',
        ApprovalRequestType.studentLeave => 'Student leave',
        ApprovalRequestType.staffLeave => 'Staff leave',
        ApprovalRequestType.feeConcession => 'Fee concession',
        ApprovalRequestType.feeStructure => 'Fee structure',
        ApprovalRequestType.inventoryPo => 'Inventory PO',
        ApprovalRequestType.refund => 'Refund',
        ApprovalRequestType.admission => 'Admission',
        ApprovalRequestType.budget => 'Budget',
        ApprovalRequestType.expense => 'Expense',
        ApprovalRequestType.payroll => 'Payroll',
        ApprovalRequestType.vendor => 'Vendor',
        ApprovalRequestType.marketing => 'Marketing',
      };
}
