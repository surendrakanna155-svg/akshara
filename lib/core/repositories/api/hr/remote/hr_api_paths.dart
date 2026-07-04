/// REST paths for the HR API module.
abstract final class HrApiPaths {
  static const String base = '/hr';

  static const String dashboard = '$base/dashboard';
  static const String employees = '$base/employees';
  static const String attendance = '$base/attendance';
  static const String leave = '$base/leave';
  static const String payroll = '$base/payroll';
  static const String recruitment = '$base/recruitment';
  static const String performance = '$base/performance';
  static const String settings = '$base/settings';
  static const String payrollRun = '$payroll/run';

  /// MOD-2 — payroll engine: salary structures + draft-run generation.
  static const String payrollStructures = '$payroll/structures';
  static const String payrollRunGenerate = '$payrollRun/generate';
  static String approveLeave(String leaveRequestId) =>
      '$base/leave/$leaveRequestId/approve';
  static String rejectLeave(String leaveRequestId) =>
      '$base/leave/$leaveRequestId/reject';

  /// HR-3 — batch approve/reject.
  static const String leaveBatchDecide = '$base/leave/batch-decide';

  static String employeeDetail(String employeeId) => '$base/employees/$employeeId';
  static String employeeStatus(String employeeId) =>
      '$base/employees/$employeeId/status';

  /// HR-D2 — probation confirm/extend.
  static String employeeProbation(String employeeId) =>
      '$base/employees/$employeeId/probation';

  // --- HR reporting / export reads (HR-1/2/4/5/6/7) -------------------------
  static const String payrollRegister = '$payroll/register';
  static const String payrollPayslips = '$payroll/payslips';
  static const String attendanceMuster = '$attendance/muster';
  static const String leaveBalances = '$leave/balances';
  static const String headcount = '$base/reports/headcount';
  static const String employeeDirectory = '$employees/export';

  // --- Final HR slice reports (HR-D1 / HR-D2) ------------------------------
  static const String documentsExpiring = '$base/documents/expiring';
  static const String probationEnding = '$base/probation/ending';
}
