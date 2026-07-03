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
  static const String feeCertificate = '$base/fee-certificate';
  static const String notices = '$base/notices';
  static const String events = '$base/events';
  static const String leave = '$base/leave';
  static String leaveCancel(String leaveId) => '$base/leave/$leaveId/cancel';
  static String leaveAttachment(String leaveId) =>
      '$base/leave/$leaveId/attachment';
  static const String profile = '$base/profile';
  static const String messages = '$base/messages';
  static const String communicationInbox = '$base/communication/inbox';
  static String communicationMessage(String communicationId) =>
      '$base/communication/$communicationId';
  static String communicationRead(String communicationId) =>
      '$base/communication/$communicationId/read';
  static String communicationAcknowledge(String communicationId) =>
      '$base/communication/$communicationId/acknowledge';
  static const String paymentsInitiate = '$base/payments/initiate';
  static const String paymentsConfirm = '$base/payments/confirm';

  static String paymentSummary(String installmentId) =>
      '$base/payments/$installmentId';

  static const String academicSummary = '/parent/experience/summary';
  static const String printableReport = '/parent/experience/report/printable';
}
