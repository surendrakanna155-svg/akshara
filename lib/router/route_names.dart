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

  // Web ERP admin shell (desktop / tablet / mobile drawer)
  static const String admin = '/admin';
  static const String admissions = '/admissions';
  static const String admissionsDashboard = '/admissions/dashboard';
  static const String admissionsLeads = '/admissions/leads';
  static const String admissionsApplications = '/admissions/applications';
  static const String admissionsEnrollment = '/admissions/enrollment';
  static const String admissionsDocuments = '/admissions/documents';

  static String admissionsLeadDetail(String leadId) =>
      '$admissionsLeads/$leadId';
  static const String admissionsApproval = '/admissions/approval';
  static const String admissionsFeeHandoff = '/admissions/fee-handoff';
  static const String admissionsReports = '/admissions/reports';
  static const String admissionsSettings = '/admissions/settings';

  /// All admissions module routes (AD-01 → AD-10).
  static const List<String> admissionsRoutes = [
    admissionsDashboard,
    admissionsLeads,
    admissionsApplications,
    admissionsEnrollment,
    admissionsDocuments,
    admissionsApproval,
    admissionsFeeHandoff,
    admissionsReports,
    admissionsSettings,
  ];
  static const String finance = '/finance';
  static const String financeDashboard = '/finance/dashboard';
  static const String financeFeeStructures = '/finance/fee-structures';
  static const String financeStudentAccounts = '/finance/student-accounts';
  static const String financeFeeAssignment = '/finance/fee-assignment';
  static const String financeCollections = '/finance/collections';

  /// All finance module routes (FN-01 → FN-05).
  static const List<String> financeRoutes = [
    financeDashboard,
    financeFeeStructures,
    financeStudentAccounts,
    financeFeeAssignment,
    financeCollections,
  ];
  static const String sis = '/sis';
  static const String sisDashboard = '/sis/dashboard';
  static const String sisStudents = '/sis/students';
  static const String sisAcademicAssignment = '/sis/academic-assignment';
  static const String sisAdmissionsConversion = '/sis/admissions-conversion';

  static String sisStudentDetail(String studentId) =>
      '$sisStudents/$studentId';

  /// All SIS module routes (SIS-01 → SIS-05).
  static const List<String> sisRoutes = [
    sisDashboard,
    sisStudents,
    sisAcademicAssignment,
    sisAdmissionsConversion,
  ];

  static const String hr = '/hr';
  static const String management = '/management';
  static const String transport = '/transport';
  static const String hostel = '/hostel';

  /// All module groups wrapped by [AdminShell].
  static const List<String> adminErpRoutes = [
    admin,
    admissions,
    finance,
    sis,
    hr,
    management,
    transport,
    hostel,
  ];
}
