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

  static String employeeDetail(String employeeId) => '$base/employees/$employeeId';
}
