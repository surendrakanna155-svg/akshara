/// REST paths for the Teacher mobile API module.
abstract final class TeacherApiPaths {
  static const String base = '/teacher';

  static const String dashboard = '$base/dashboard';
  static const String attendanceClasses = '$base/attendance/classes';
  static const String attendanceStudents = '$base/attendance/students';
  static const String homework = '$base/homework';
  static const String homeworkCreate = '$base/homework';
  static const String examsUpcoming = '$base/exams/upcoming';
  static const String examsMarksEntry = '$base/exams/marks-entry';
  static const String examsMarks = '$base/exams/marks';
  static const String timetable = '$base/timetable';
  static const String leave = '$base/leave';
  static const String leaveBalance = '$base/leave/balance';
  static const String messages = '$base/messages';
  static const String parentCommunication = '$base/parent-communication';
  static const String parentCommunicationConcerns = '$base/parent-communication/concerns';
  static const String attendanceDraft = '$base/attendance/draft';
  static const String attendanceSubmit = '$base/attendance/submit';

  static String homeworkReview(String submissionId) =>
      '$base/homework/submissions/$submissionId/review';

  // HWK-2 — not-submitted list for an assignment.
  static String homeworkNonSubmitters(String homeworkId) =>
      '$base/homework/$homeworkId/non-submitters';
  // HWK-D1 — manual parent no-submit nudge for an assignment.
  static String homeworkNotifyNonSubmitters(String homeworkId) =>
      '$base/homework/$homeworkId/notify-non-submitters';
  // HWK-6 — bulk mark-reviewed.
  static const String homeworkBulkReview = '$base/homework/bulk-review';
  // HWK-5 — homework history (supports ?from=&to=).
  static const String homeworkHistory = '$base/homework/history';

  static String examMark(String markEntryId) => '$base/exams/marks/$markEntryId';

  static String examPublish(String examId) => '$base/exams/$examId/publish';
  static String examProcess(String examId) => '$base/exams/$examId/process';
}
