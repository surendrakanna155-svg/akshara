import '../../../features/finance/finance_models.dart';
import '../../../features/finance/finance_requests.dart';
import '../../../features/finance/intelligence/finance_intelligence_models.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for finance data access (mock or API).
abstract class FinanceRepository {
  Future<FinanceDashboardData> getDashboard({required RepositoryQuery query});
  Future<PaginatedResult<CollectionPayment>> getCollections(
      {required RepositoryQuery query});
  Future<DailyCollectionSummary> getDailySummary(
      {required RepositoryQuery query});
  Future<PaginatedResult<FinanceFeeStructure>> getFeeStructures(
      {required RepositoryQuery query, required String academicYear});
  Future<PaginatedResult<String>> getAcademicYears(
      {required RepositoryQuery query});
  Future<PaginatedResult<StudentFeeAccount>> getStudentAccounts(
      {required RepositoryQuery query});
  Future<PaginatedResult<InstallmentPlan>> getInstallmentPlans(
      {required RepositoryQuery query});

  Future<CollectionDetail?> getCollectionDetail(
      {required RepositoryQuery query, required String collectionId});

  Future<FinanceCollectionResult> createCollection({
    required RepositoryQuery query,
    required CreateCollectionRequest request,
  });

  Future<QrPaymentSession> createQrPaymentSession({
    required RepositoryQuery query,
    required CreateQrPaymentSessionRequest request,
  });

  Future<QrPaymentSession?> getQrPaymentSession({
    required RepositoryQuery query,
    required String sessionId,
  });

  Future<QrPaymentSession> confirmQrPaymentSession({
    required RepositoryQuery query,
    required String sessionId,
    required ConfirmQrPaymentRequest request,
  });

  Future<FinanceCollectionResult> cancelCollection({
    required RepositoryQuery query,
    required String collectionId,
    // FIN-D3: a cancellation reason is mandatory.
    required String reason,
  });

  // ── FIN-D3: cancelled register ─────────────────────────────────────────────
  Future<List<CancelledCollection>> getCancelledCollections({
    required RepositoryQuery query,
  });

  // ── FIN-D5: late-fee accrual + waive ───────────────────────────────────────
  Future<LateFeeAccrualResult> accrueLateFees({
    required RepositoryQuery query,
  });

  Future<FinanceInvoice> waiveLateFee({
    required RepositoryQuery query,
    required String invoiceId,
    required String reason,
  });

  // ── FIN-D1: day-close lock ─────────────────────────────────────────────────
  Future<List<DayCloseEntry>> getDayCloseEntries({
    required RepositoryQuery query,
    String? from,
    String? to,
  });

  Future<DayCloseEntry> closeDay({
    required RepositoryQuery query,
    String? date,
  });

  Future<DayCloseEntry> reopenDay({
    required RepositoryQuery query,
    required String date,
  });

  // ── FIN-2: printable student ledger ────────────────────────────────────────
  Future<StudentLedger> getStudentLedger({
    required RepositoryQuery query,
    required String studentAccountId,
  });

  Future<OfflinePaymentRecord> recordOfflinePayment({
    required RepositoryQuery query,
    required RecordOfflinePaymentRequest request,
  });

  Future<PaginatedResult<OfflinePaymentRecord>> listOfflinePayments({
    required RepositoryQuery query,
  });

  Future<OfflinePaymentRecord> reconcileOfflinePayment({
    required RepositoryQuery query,
    required String offlinePaymentId,
    required ReconcileOfflinePaymentRequest request,
  });

  /// FIN-R7: mark a pending instrument (cheque/DD/PDC) as bounced. Tracking-only.
  Future<OfflinePaymentRecord> bounceOfflinePayment({
    required RepositoryQuery query,
    required String offlinePaymentId,
    required BounceOfflinePaymentRequest request,
  });

  Future<DefaultersDashboardData> getDefaultersDashboard(
      {required RepositoryQuery query});
  Future<PaginatedResult<RefundRequest>> getRefundRequests(
      {required RepositoryQuery query});
  Future<RefundRequest?> getRefund({
    required RepositoryQuery query,
    required String refundId,
  });
  Future<DiscountsDashboardData> getDiscountsDashboard(
      {required RepositoryQuery query});
  Future<FinanceReportsData> getReportsData({required RepositoryQuery query});
  Future<FinanceSettingsData> getSettings({required RepositoryQuery query});

  Future<FinanceFeeStructure> createFeeStructure({
    required RepositoryQuery query,
    required CreateFeeStructureRequest request,
  });

  Future<FinanceFeeStructure> updateFeeStructure({
    required RepositoryQuery query,
    required String feeStructureId,
    required UpdateFeeStructureRequest request,
  });

  Future<StudentFeeAccount> createStudentAccount({
    required RepositoryQuery query,
    required CreateStudentAccountRequest request,
  });

  Future<StudentFeeAccount> updateStudentAccount({
    required RepositoryQuery query,
    required String accountId,
    required UpdateStudentAccountRequest request,
  });

  Future<StudentFeeAccount> assignFeePlan({
    required RepositoryQuery query,
    required AssignFeePlanRequest request,
  });

  Future<RefundRequest> createRefund({
    required RepositoryQuery query,
    required CreateRefundRequest request,
  });

  Future<RefundRequest> approveRefund({
    required RepositoryQuery query,
    required String refundId,
    ApproveRefundRequest request = const ApproveRefundRequest(),
  });

  Future<RefundRequest> rejectRefund({
    required RepositoryQuery query,
    required String refundId,
  });

  Future<FinanceReceiptDetail?> getReceipt({
    required RepositoryQuery query,
    required String receiptId,
  });

  Future<PaginatedResult<FinanceInvoice>> getInvoices({
    required RepositoryQuery query,
  });

  Future<FinanceInvoice?> getInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  });

  // ── FIN-6: invoice installment / due schedule ──────────────────────────────
  Future<List<InstallmentScheduleEntry>> getInvoiceInstallments({
    required RepositoryQuery query,
    required String invoiceId,
  });

  // ── FIN-9: head-wise dues analytics ────────────────────────────────────────
  Future<List<HeadWiseDue>> getHeadWiseDues({
    required RepositoryQuery query,
  });

  Future<FinanceInvoice> issueInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  });

  Future<FinanceInvoice> cancelInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  });

  Future<ScholarshipCatalogItem> createScholarship({
    required RepositoryQuery query,
    required CreateScholarshipRequest request,
  });

  Future<ScholarshipCatalogItem> updateScholarship({
    required RepositoryQuery query,
    required String scholarshipId,
    required UpdateScholarshipRequest request,
  });

  Future<DiscountRule> createDiscountRule({
    required RepositoryQuery query,
    required CreateDiscountRuleRequest request,
  });

  Future<DiscountRule> updateDiscountRule({
    required RepositoryQuery query,
    required String ruleId,
    required UpdateDiscountRuleRequest request,
  });

  Future<FinanceSettingsData> updateSettings({
    required RepositoryQuery query,
    required UpdateFinanceSettingsRequest request,
  });

  Future<FinanceCopilotData> getFinanceCopilot(
      {required RepositoryQuery query});

  Future<FinanceExecutiveData> getFinanceExecutiveDashboard(
      {required RepositoryQuery query});

  // ── FIN-R1..R5: fee-recovery CRM ───────────────────────────────────────────
  Future<RecoveryContact> logRecoveryContact({
    required RepositoryQuery query,
    required LogRecoveryContactRequest request,
  });

  Future<List<RecoveryContact>> listRecoveryContacts({
    required RepositoryQuery query,
    required String studentId,
  });

  Future<PromiseToPay> createPromiseToPay({
    required RepositoryQuery query,
    required CreatePromiseToPayRequest request,
  });

  Future<List<PromiseToPay>> listPromisesToPay({
    required RepositoryQuery query,
    PromiseToPayStatus? status,
  });

  Future<PromiseToPay> resolvePromiseToPay({
    required RepositoryQuery query,
    required String promiseId,
    required ResolvePromiseToPayRequest request,
  });

  Future<RecoveryDashboardData> getRecoveryDashboard({
    required RepositoryQuery query,
  });

  /// FIN-R2 — the telecaller call queue: defaulters ranked (server-side) into
  /// the order they should be called.
  Future<List<CallQueueEntry>> getCallQueue({
    required RepositoryQuery query,
  });

  /// FIN-R6 — set a collector's monthly collection target (principal action).
  /// Returns the refreshed recovery dashboard so attainment reflects the change.
  Future<RecoveryDashboardData> setCollectionTarget({
    required RepositoryQuery query,
    required SetCollectionTargetRequest request,
  });
}
