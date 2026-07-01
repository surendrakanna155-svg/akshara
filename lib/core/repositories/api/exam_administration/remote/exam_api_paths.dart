/// REST paths for exam administration API (F4).
abstract final class ExamApiPaths {
  static const String base = '/academics/exams';

  static String exam(String examId) => '$base/$examId';

  static String schedule(String examId) => '$base/$examId/schedule';

  static String openMarks(String examId) => '$base/$examId/open-marks';

  static String marks(String examId) => '$base/$examId/marks';

  /// EXM-1 — fast bulk marks save for one exam.
  static String marksBatch(String examId) => '$base/$examId/marks/batch';

  /// EXM-2 — marks-entry progress board (exams awaiting marks for the school).
  static const String progress = '$base/progress';

  static String markEntry(String markEntryId) => '$base/marks/$markEntryId';

  static String process(String examId) => '$base/$examId/process';

  static String verifyCoordinator(String examId) =>
      '$base/$examId/verify-coordinator';

  static String publish(String examId) => '$base/$examId/publish';

  static String publishedResults(String sisStudentId) =>
      '$base/students/$sisStudentId/published';

  static String remarks(String examId) => '$base/$examId/remarks';

  static String remark(String examId, String sisStudentId) =>
      '$base/$examId/remarks/$sisStudentId';

  // ── EXM-3/4/5/7 — read-only exam reports ─────────────────────────────────

  /// EXM-3 — tabulation register for a class over a term (`?term=`).
  static String tabulation(String classLabel) =>
      '$base/class/${Uri.encodeComponent(classLabel)}/tabulation';

  /// EXM-4a — top-N students by marks for one exam (`?limit=`).
  static String toppers(String examId) => '$base/$examId/toppers';

  /// EXM-4b — merit list for a class over a term (`?term=`).
  static String merit(String classLabel) =>
      '$base/class/${Uri.encodeComponent(classLabel)}/merit';

  /// EXM-5 — pass/fail + grade distribution for one exam.
  static String distribution(String examId) => '$base/$examId/distribution';

  /// EXM-7 — datesheet (exam schedule) for a class over a term (`?term=`).
  static String datesheet(String classLabel) =>
      '$base/class/${Uri.encodeComponent(classLabel)}/datesheet';
}
