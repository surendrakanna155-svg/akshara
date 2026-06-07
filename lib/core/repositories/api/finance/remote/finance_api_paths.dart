/// REST paths for the Finance API module.
abstract final class FinanceApiPaths {
  static const String base = '/finance';

  static const String dashboard = '$base/dashboard';
  static const String collections = '$base/collections';
  static const String dailySummary = '$base/collections/daily-summary';
  static const String feeStructures = '$base/fee-structures';
  static const String academicYears = '$base/academic-years';
  static const String studentAccounts = '$base/student-accounts';
  static const String feeAssignment = '$base/fee-assignment';

  /// @deprecated Use [feeAssignment].
  static const String installmentPlans = feeAssignment;
  static const String defaulters = '$base/defaulters';
  static const String refunds = '$base/refunds';
  static const String discounts = '$base/discounts';
  static const String reports = '$base/reports';
  static const String settings = '$base/settings';
  static const String scholarships = '$base/scholarships';
  static const String feeAssignmentAssign = '$feeAssignment/assign';

  static String collectionDetail(String id) => '$base/collections/$id';
  static String feeStructure(String id) => '$feeStructures/$id';
  static String studentAccount(String id) => '$studentAccounts/$id';
  static String refund(String id) => '$refunds/$id';
  static String refundApprove(String id) => '${refund(id)}/approve';
  static String scholarship(String id) => '$scholarships/$id';
}
