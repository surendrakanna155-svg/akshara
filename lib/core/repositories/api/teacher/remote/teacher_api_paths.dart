/// REST paths for the Teacher mobile API module.
abstract final class TeacherApiPaths {
  static const String base = '/teacher';

  static const String dashboard = '$base/dashboard';
  static const String attendanceClasses = '$base/attendance/classes';
  static const String attendanceStudents = '$base/attendance/students';
  static const String homework = '$base/homework';
  static const String examsUpcoming = '$base/exams/upcoming';
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

  static String examMark(String markEntryId) => '$base/exams/marks/$markEntryId';

  static String examPublish(String examId) => '$base/exams/$examId/publish';
}
