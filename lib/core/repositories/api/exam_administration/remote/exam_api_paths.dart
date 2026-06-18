/// REST paths for exam administration API (F4).
abstract final class ExamApiPaths {
  static const String base = '/academics/exams';

  static String exam(String examId) => '$base/$examId';

  static String schedule(String examId) => '$base/$examId/schedule';

  static String openMarks(String examId) => '$base/$examId/open-marks';

  static String marks(String examId) => '$base/$examId/marks';

  static String markEntry(String markEntryId) => '$base/marks/$markEntryId';

  static String process(String examId) => '$base/$examId/process';

  static String verifyCoordinator(String examId) =>
      '$base/$examId/verify-coordinator';

  static String publish(String examId) => '$base/$examId/publish';

  static String publishedResults(String sisStudentId) =>
      '$base/students/$sisStudentId/published';
}
