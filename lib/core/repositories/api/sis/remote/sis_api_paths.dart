/// REST paths for the SIS API module.
abstract final class SisApiPaths {
  static const String base = '/sis';

  static const String dashboard = '$base/dashboard';
  static const String students = '$base/students';
  static const String academicAssignment = '$base/academic-assignment';
  static const String admissionsConversion = '$base/admissions-conversion';

  static String studentProfile(String studentId) => '$base/students/$studentId';

  static String studentStatus(String studentId) =>
      '$base/students/$studentId/status';
}
