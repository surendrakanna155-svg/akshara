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
  static String approveLeave(String leaveRequestId) =>
      '$base/leave/$leaveRequestId/approve';
  static String rejectLeave(String leaveRequestId) =>
      '$base/leave/$leaveRequestId/reject';

  static String employeeDetail(String employeeId) => '$base/employees/$employeeId';
  static String employeeStatus(String employeeId) =>
      '$base/employees/$employeeId/status';

  // --- HR reporting / export reads (HR-1/2/4/5/6/7) -------------------------
  static const String payrollRegister = '$payroll/register';
  static const String payrollPayslips = '$payroll/payslips';
  static const String attendanceMuster = '$attendance/muster';
  static const String leaveBalances = '$leave/balances';
  static const String headcount = '$base/reports/headcount';
  static const String employeeDirectory = '$employees/export';
}
