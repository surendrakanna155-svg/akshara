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
  static const String parentFees = '/parent/fees';
  static const String parentNotifications = '/parent/notifications';

  // Teacher app (mobile)
  static const String teacher = '/teacher';
  static const String teacherDashboard = '/teacher/dashboard';

  // Student app (mobile)
  static const String student = '/student';
  static const String studentDashboard = '/student/dashboard';
}
