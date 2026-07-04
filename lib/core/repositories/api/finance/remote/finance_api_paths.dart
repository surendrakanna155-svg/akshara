/// REST paths for the Finance API module.
abstract final class FinanceApiPaths {
  static const String base = '/finance';

  static const String dashboard = '$base/dashboard';
  static const String collections = '$base/collections';
  static const String offlinePayments = '$base/payments/offline';
  static const String qrPayments = '$base/payments/qr';
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
  static const String intelligenceCopilot = '$base/intelligence/copilot';
  static const String intelligenceExecutive = '$base/intelligence/executive';
  static const String scholarships = '$base/scholarships';

  // FIN-D3: cancelled register.
  static const String collectionsCancelled = '$base/collections/cancelled';

  // FIN-D5: late-fee accrual.
  static const String lateFeesAccrue = '$base/late-fees/accrue';

  // FIN-D1: day-close lock.
  static const String dayClose = '$base/day-close';
  static String dayCloseReopen(String date) => '$dayClose/$date/reopen';

  static String collectionDetail(String id) => '$base/collections/$id';
  static String collectionCancel(String id) => '${collectionDetail(id)}/cancel';
  static String offlinePaymentReconcile(String id) =>
      '$offlinePayments/$id/reconcile';
  static String qrPaymentSession(String id) => '$qrPayments/$id';
  static String qrPaymentConfirm(String id) =>
      '${qrPaymentSession(id)}/confirm';
  static String feeStructure(String id) => '$feeStructures/$id';
  static String feeAssignment(String id) => '$feeAssignments/$id';
  static String studentAccount(String studentId) =>
      '$studentAccounts/$studentId';
  static String receipt(String id) => '$receipts/$id';
  static String refund(String id) => '$refunds/$id';
  static String refundApprove(String id) => '${refund(id)}/approve';
  static String refundReject(String id) => '${refund(id)}/reject';
  static String scholarship(String id) => '$scholarships/$id';
  static String discount(String id) => '$discounts/$id';
  static const String invoices = '$base/invoices';

  static String invoice(String id) => '$invoices/$id';
  static String invoiceIssue(String id) => '${invoice(id)}/issue';
  static String invoiceCancel(String id) => '${invoice(id)}/cancel';
  // FIN-D5: waive a single invoice's late fee.
  static String invoiceWaiveLateFee(String id) => '${invoice(id)}/waive-late-fee';

  // FIN-6: invoice installment / due schedule.
  static String invoiceInstallments(String id) => '${invoice(id)}/installments';

  // FIN-9: head-wise dues + outstanding analytics.
  static const String analyticsHeadWiseDues = '$base/analytics/head-wise-dues';

  // FIN-2: printable student ledger / fee statement.
  static String studentLedger(String studentAccountId) =>
      '${studentAccount(studentAccountId)}/ledger';

  // FIN-R1..R5 — fee-recovery CRM.
  static const String recovery = '$base/recovery';
  static const String recoveryContacts = '$recovery/contacts';
  static const String recoveryPromises = '$recovery/promises';
  static const String recoveryDashboard = '$recovery/dashboard';
  static const String recoveryCallQueue = '$recovery/call-queue';

  static String recoveryContactsForStudent(String studentId) =>
      '$recoveryContacts/$studentId';
  static String recoveryPromiseResolve(String promiseId) =>
      '$recoveryPromises/$promiseId/resolve';
}
