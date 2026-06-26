/// REST paths for the Hostel API module.
abstract final class HostelApiPaths {
  static const String base = '/hostel';

  static const String dashboard = '$base/dashboard';
  static const String students = '$base/students';
  static const String rooms = '$base/rooms';
  static const String attendance = '$base/attendance';
  static const String leave = '$base/leave';
  static const String mess = '$base/mess';
  static const String visitors = '$base/visitors';
  static const String reports = '$base/reports';
  static const String occupancyMetrics = '$base/occupancy-metrics';

  static const String recordAttendance = attendance;
  static const String recordMess = mess;

  static String assignRoom(String hostelStudentId) =>
      '$students/$hostelStudentId/room';

  static String checkout(String hostelStudentId) =>
      '$students/$hostelStudentId/checkout';
}
