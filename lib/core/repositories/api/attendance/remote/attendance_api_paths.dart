/// REST paths for attendance API (F5).
abstract final class AttendanceApiPaths {
  static const String base = '/attendance';

  static const String sessions = '$base/sessions';
  static const String corrections = '$base/corrections';

  static String session(String sessionId) => '$sessions/$sessionId';

  static String correction(String correctionId) => '$corrections/$correctionId';

  static String correctionStatus(String correctionId) =>
      '$corrections/$correctionId/status';
}
