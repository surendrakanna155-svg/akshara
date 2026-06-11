/// REST paths for the Parent mobile API module.
abstract final class ParentApiPaths {
  static const String base = '/parent';

  static const String dashboard = '$base/dashboard';
  static const String attendance = '$base/attendance';
  static const String homework = '$base/homework';
  static const String exams = '$base/exams';
  static const String timetable = '$base/timetable';
  static const String fees = '$base/fees';
  static const String receipts = '$base/receipts';
  static const String notices = '$base/notices';
  static const String events = '$base/events';
  static const String leave = '$base/leave';
  static const String profile = '$base/profile';
  static const String paymentsInitiate = '$base/payments/initiate';
  static const String paymentsConfirm = '$base/payments/confirm';

  static String paymentSummary(String installmentId) =>
      '$base/payments/$installmentId';

  static const String academicSummary = '/parent/experience/summary';
  static const String printableReport = '/parent/experience/report/printable';
}
