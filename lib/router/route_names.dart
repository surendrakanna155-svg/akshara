/// Canonical path constants for [GoRouter] configuration.
abstract final class RouteNames {
  static const String root = '/';

  // Auth (P-01 → P-03)
  static const String splash = '/splash';
  static const String login = '/login';
  static const String otpVerification = '/otp';

  // Parent app (mobile)
  static const String parent = '/parent';
  static const String parentDashboard = '/parent/dashboard';
  static const String parentAttendance = '/parent/attendance';
  static const String parentTimetable = '/parent/timetable';
  static const String parentHomework = '/parent/homework';
  static const String parentExams = '/parent/exams';
  static const String parentNotices = '/parent/notices';
  static const String parentEvents = '/parent/events';
  static const String parentProfile = '/parent/profile';
  static const String parentFees = '/parent/fees';
  static const String parentPayment = '/parent/payment';
  static const String parentReceipts = '/parent/receipts';
  static const String parentLeave = '/parent/leave';
  static const String parentNotifications = '/parent/notifications';

  static String parentReceiptDetail(String receiptId) =>
      '$parentReceipts/$receiptId';

  // Teacher app (mobile)
  static const String teacher = '/teacher';
  static const String teacherDashboard = '/teacher/dashboard';
  static const String teacherAttendance = '/teacher/attendance';
  static const String teacherTimetable = '/teacher/timetable';
  static const String teacherHomework = '/teacher/homework';
  static const String teacherExams = '/teacher/exams';
  static const String teacherMessages = '/teacher/messages';
  static const String teacherLeave = '/teacher/leave';

  static String teacherConversation(String threadId) =>
      '$teacherMessages/$threadId';

  // Student app (mobile)
  static const String student = '/student';
  static const String studentDashboard = '/student/dashboard';
  static const String studentAttendance = '/student/attendance';
  static const String studentTimetable = '/student/timetable';
  static const String studentHomework = '/student/homework';
  static const String studentExams = '/student/exams';
  static const String studentNotices = '/student/notices';
  static const String studentProfile = '/student/profile';
}
