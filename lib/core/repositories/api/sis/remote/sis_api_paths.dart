/// REST paths for the SIS API module.
abstract final class SisApiPaths {
  static const String base = '/sis';

  static const String dashboard = '$base/dashboard';
  static const String students = '$base/students';
  static const String enrollments = '$base/enrollments';
  static const String admissionsConversion = '$base/admissions-conversion';

  /// @deprecated Use [enrollments] — retained for mock/catalog references only.
  static const String academicAssignment = '$base/academic-assignment';

  static String studentProfile(String studentId) => '$base/students/$studentId';

  static String studentStatus(String studentId) =>
      '$base/students/$studentId/status';

  static String studentDocuments(String studentId) =>
      '$base/students/$studentId/documents';

  static String enrollment(String enrollmentId) =>
      '$base/enrollments/$enrollmentId';
}
