/// REST paths for the Finance API module.
abstract final class FinanceApiPaths {
  static const String base = '/finance';

  static const String dashboard = '$base/dashboard';
  static const String collections = '$base/collections';
  static const String dailySummary = '$base/collections/daily-summary';
  static const String feeStructures = '$base/fee-structures';
  static const String feeAssignments = '$base/fee-assignments';
  static const String studentAccounts = '$base/student-accounts';
  static const String feeAssignmentAssign = '$base/fee-assignment/assign';
  static const String receipts = '$base/receipts';
  static const String defaulters = '$base/defaulters';
  static const String refunds = '$base/refunds';
  static const String discounts = '$base/discounts';
  static const String reports = '$base/reports';
  static const String settings = '$base/settings';
  static const String scholarships = '$base/scholarships';

  static String collectionDetail(String id) => '$base/collections/$id';
  static String collectionCancel(String id) => '${collectionDetail(id)}/cancel';
  static String feeStructure(String id) => '$feeStructures/$id';
  static String feeAssignment(String id) => '$feeAssignments/$id';
  static String studentAccount(String studentId) => '$studentAccounts/$studentId';
  static String receipt(String id) => '$receipts/$id';
  static String refund(String id) => '$refunds/$id';
  static String refundApprove(String id) => '${refund(id)}/approve';
  static String refundReject(String id) => '${refund(id)}/reject';
  static String scholarship(String id) => '$scholarships/$id';
  static const String invoices = '$base/invoices';

  static String invoice(String id) => '$invoices/$id';
  static String invoiceIssue(String id) => '${invoice(id)}/issue';
  static String invoiceCancel(String id) => '${invoice(id)}/cancel';
}
