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

  /// EXM-6 — remind teachers about marks-entry past deadline (rides XCT-2).
  static const String remindMarks = '$base/marks/remind';

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

  // ── EXM-D1/D2/D4/D5 — final exams slice ────────────────────────────────────

  /// EXM-D1 — batch report cards for a class over a term (`?term=`).
  static String reportCards(String classLabel) =>
      '$base/class/${Uri.encodeComponent(classLabel)}/report-cards';

  /// EXM-D2 — record a grace / moderation delta for one (exam, student).
  static String grace(String examId, String sisStudentId) =>
      '$base/$examId/students/${Uri.encodeComponent(sisStudentId)}/grace';

  /// EXM-D2 — grace / moderation breakdown for an exam (coordinator-only).
  static String adjustments(String examId) => '$base/$examId/adjustments';

  /// EXM-D4 — hall tickets (admit cards) for an exam.
  static String hallTickets(String examId) => '$base/$examId/hall-tickets';

  /// EXM-D5 — (re)generate the seating plan for an exam.
  static String seatingGenerate(String examId) =>
      '$base/$examId/seating/generate';

  /// EXM-D5 — read the seating plan for an exam.
  static String seating(String examId) => '$base/$examId/seating';
}
