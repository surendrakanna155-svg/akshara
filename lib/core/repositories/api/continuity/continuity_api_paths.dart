abstract final class ContinuityApiPaths {
  static const String base = '/sis/continuity';
  static const String preview = '$base/preview';
  static const String messageOwnership = '$base/message-ownership';
  static const String timetable = '$base/timetable';
  static const String parentNotifications = '$base/parent-notifications';
  static const String homework = '$base/homework';

  static String execute(String planId) => '$base/$planId/execute';
  static String auditTrail(String migrationId) => '$base/$migrationId/audit';
}
