import '../../interfaces/finance_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/finance/finance_models.dart';
import '../../../../features/finance/finance_requests.dart';
import '../../../../features/finance/intelligence/finance_intelligence_models.dart';
import 'api_finance_repository.dart';

/// Thin wrapper routing all finance operations to [ApiFinanceRepository].
class HybridFinanceRepository implements FinanceRepository {
  HybridFinanceRepository({required ApiFinanceRepository api}) : _api = api;

  final ApiFinanceRepository _api;

  @override
  Future<FinanceDashboardData> getDashboard({required RepositoryQuery query}) =>
      _api.getDashboard(query: query);

  @override
  Future<PaginatedResult<CollectionPayment>> getCollections({
    required RepositoryQuery query,
  }) =>
      _api.getCollections(query: query);

  @override
  Future<DailyCollectionSummary> getDailySummary({
    required RepositoryQuery query,
  }) =>
      _api.getDailySummary(query: query);

  @override
  Future<PaginatedResult<FinanceFeeStructure>> getFeeStructures({
    required RepositoryQuery query,
    required String academicYear,
  }) =>
      _api.getFeeStructures(query: query, academicYear: academicYear);

  @override
  Future<PaginatedResult<String>> getAcademicYears({
    required RepositoryQuery query,
  }) =>
      _api.getAcademicYears(query: query);

  @override
  Future<PaginatedResult<StudentFeeAccount>> getStudentAccounts({
    required RepositoryQuery query,
  }) =>
      _api.getStudentAccounts(query: query);

  @override
  Future<PaginatedResult<InstallmentPlan>> getInstallmentPlans({
    required RepositoryQuery query,
  }) =>
      _api.getInstallmentPlans(query: query);

  @override
  Future<CollectionDetail?> getCollectionDetail({
    required RepositoryQuery query,
    required String collectionId,
  }) =>
      _api.getCollectionDetail(query: query, collectionId: collectionId);

  @override
  Future<FinanceCollectionResult> createCollection({
    required RepositoryQuery query,
    required CreateCollectionRequest request,
  }) =>
      _api.createCollection(query: query, request: request);

  @override
  Future<QrPaymentSession> createQrPaymentSession({
    required RepositoryQuery query,
    required CreateQrPaymentSessionRequest request,
  }) =>
      _api.createQrPaymentSession(query: query, request: request);

  @override
  Future<QrPaymentSession?> getQrPaymentSession({
    required RepositoryQuery query,
    required String sessionId,
  }) =>
      _api.getQrPaymentSession(query: query, sessionId: sessionId);

  @override
  Future<QrPaymentSession> confirmQrPaymentSession({
    required RepositoryQuery query,
    required String sessionId,
    required ConfirmQrPaymentRequest request,
  }) =>
      _api.confirmQrPaymentSession(
        query: query,
        sessionId: sessionId,
        request: request,
      );

  @override
  Future<FinanceCollectionResult> cancelCollection({
    required RepositoryQuery query,
    required String collectionId,
    required String reason,
  }) =>
      _api.cancelCollection(
        query: query,
        collectionId: collectionId,
        reason: reason,
      );

  @override
  Future<List<CancelledCollection>> getCancelledCollections({
    required RepositoryQuery query,
  }) =>
      _api.getCancelledCollections(query: query);

  @override
  Future<LateFeeAccrualResult> accrueLateFees({
    required RepositoryQuery query,
  }) =>
      _api.accrueLateFees(query: query);

  @override
  Future<FinanceInvoice> waiveLateFee({
    required RepositoryQuery query,
    required String invoiceId,
    required String reason,
  }) =>
      _api.waiveLateFee(query: query, invoiceId: invoiceId, reason: reason);

  @override
  Future<List<DayCloseEntry>> getDayCloseEntries({
    required RepositoryQuery query,
    String? from,
    String? to,
  }) =>
      _api.getDayCloseEntries(query: query, from: from, to: to);

  @override
  Future<DayCloseEntry> closeDay({
    required RepositoryQuery query,
    String? date,
  }) =>
      _api.closeDay(query: query, date: date);

  @override
  Future<DayCloseEntry> reopenDay({
    required RepositoryQuery query,
    required String date,
  }) =>
      _api.reopenDay(query: query, date: date);

  @override
  Future<StudentLedger> getStudentLedger({
    required RepositoryQuery query,
    required String studentAccountId,
  }) =>
      _api.getStudentLedger(query: query, studentAccountId: studentAccountId);

  @override
  Future<OfflinePaymentRecord> recordOfflinePayment({
    required RepositoryQuery query,
    required RecordOfflinePaymentRequest request,
  }) =>
      _api.recordOfflinePayment(query: query, request: request);

  @override
  Future<PaginatedResult<OfflinePaymentRecord>> listOfflinePayments({
    required RepositoryQuery query,
  }) =>
      _api.listOfflinePayments(query: query);

  @override
  Future<OfflinePaymentRecord> reconcileOfflinePayment({
    required RepositoryQuery query,
    required String offlinePaymentId,
    required ReconcileOfflinePaymentRequest request,
  }) =>
      _api.reconcileOfflinePayment(
        query: query,
        offlinePaymentId: offlinePaymentId,
        request: request,
      );

  @override
  Future<DefaultersDashboardData> getDefaultersDashboard({
    required RepositoryQuery query,
  }) =>
      _api.getDefaultersDashboard(query: query);

  @override
  Future<PaginatedResult<RefundRequest>> getRefundRequests({
    required RepositoryQuery query,
  }) =>
      _api.getRefundRequests(query: query);

  @override
  Future<RefundRequest?> getRefund({
    required RepositoryQuery query,
    required String refundId,
  }) =>
      _api.getRefund(query: query, refundId: refundId);

  @override
  Future<DiscountsDashboardData> getDiscountsDashboard({
    required RepositoryQuery query,
  }) =>
      _api.getDiscountsDashboard(query: query);

  @override
  Future<FinanceReportsData> getReportsData({
    required RepositoryQuery query,
  }) =>
      _api.getReportsData(query: query);

  @override
  Future<FinanceSettingsData> getSettings({
    required RepositoryQuery query,
  }) =>
      _api.getSettings(query: query);

  @override
  Future<FinanceFeeStructure> createFeeStructure({
    required RepositoryQuery query,
    required CreateFeeStructureRequest request,
  }) =>
      _api.createFeeStructure(query: query, request: request);

  @override
  Future<FinanceFeeStructure> updateFeeStructure({
    required RepositoryQuery query,
    required String feeStructureId,
    required UpdateFeeStructureRequest request,
  }) =>
      _api.updateFeeStructure(
        query: query,
        feeStructureId: feeStructureId,
        request: request,
      );

  @override
  Future<StudentFeeAccount> createStudentAccount({
    required RepositoryQuery query,
    required CreateStudentAccountRequest request,
  }) =>
      _api.createStudentAccount(query: query, request: request);

  @override
  Future<StudentFeeAccount> updateStudentAccount({
    required RepositoryQuery query,
    required String accountId,
    required UpdateStudentAccountRequest request,
  }) =>
      _api.updateStudentAccount(
        query: query,
        accountId: accountId,
        request: request,
      );

  @override
  Future<StudentFeeAccount> assignFeePlan({
    required RepositoryQuery query,
    required AssignFeePlanRequest request,
  }) =>
      _api.assignFeePlan(query: query, request: request);

  @override
  Future<RefundRequest> createRefund({
    required RepositoryQuery query,
    required CreateRefundRequest request,
  }) =>
      _api.createRefund(query: query, request: request);

  @override
  Future<RefundRequest> approveRefund({
    required RepositoryQuery query,
    required String refundId,
    ApproveRefundRequest request = const ApproveRefundRequest(),
  }) =>
      _api.approveRefund(
        query: query,
        refundId: refundId,
        request: request,
      );

  @override
  Future<RefundRequest> rejectRefund({
    required RepositoryQuery query,
    required String refundId,
  }) =>
      _api.rejectRefund(query: query, refundId: refundId);

  @override
  Future<FinanceReceiptDetail?> getReceipt({
    required RepositoryQuery query,
    required String receiptId,
  }) =>
      _api.getReceipt(query: query, receiptId: receiptId);

  @override
  Future<PaginatedResult<FinanceInvoice>> getInvoices({
    required RepositoryQuery query,
  }) =>
      _api.getInvoices(query: query);

  @override
  Future<FinanceInvoice?> getInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  }) =>
      _api.getInvoice(query: query, invoiceId: invoiceId);

  @override
  Future<FinanceInvoice> issueInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  }) =>
      _api.issueInvoice(query: query, invoiceId: invoiceId);

  @override
  Future<FinanceInvoice> cancelInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  }) =>
      _api.cancelInvoice(query: query, invoiceId: invoiceId);

  @override
  Future<ScholarshipCatalogItem> createScholarship({
    required RepositoryQuery query,
    required CreateScholarshipRequest request,
  }) =>
      _api.createScholarship(query: query, request: request);

  @override
  Future<ScholarshipCatalogItem> updateScholarship({
    required RepositoryQuery query,
    required String scholarshipId,
    required UpdateScholarshipRequest request,
  }) =>
      _api.updateScholarship(
        query: query,
        scholarshipId: scholarshipId,
        request: request,
      );

  @override
  Future<DiscountRule> createDiscountRule({
    required RepositoryQuery query,
    required CreateDiscountRuleRequest request,
  }) =>
      _api.createDiscountRule(query: query, request: request);

  @override
  Future<DiscountRule> updateDiscountRule({
    required RepositoryQuery query,
    required String ruleId,
    required UpdateDiscountRuleRequest request,
  }) =>
      _api.updateDiscountRule(query: query, ruleId: ruleId, request: request);

  @override
  Future<FinanceSettingsData> updateSettings({
    required RepositoryQuery query,
    required UpdateFinanceSettingsRequest request,
  }) =>
      _api.updateSettings(query: query, request: request);

  @override
  Future<FinanceCopilotData> getFinanceCopilot(
          {required RepositoryQuery query}) =>
      _api.getFinanceCopilot(query: query);

  @override
  Future<FinanceExecutiveData> getFinanceExecutiveDashboard(
          {required RepositoryQuery query}) =>
      _api.getFinanceExecutiveDashboard(query: query);

  // ── FIN-R1..R5: fee-recovery CRM ───────────────────────────────────────────
  @override
  Future<RecoveryContact> logRecoveryContact({
    required RepositoryQuery query,
    required LogRecoveryContactRequest request,
  }) =>
      _api.logRecoveryContact(query: query, request: request);

  @override
  Future<List<RecoveryContact>> listRecoveryContacts({
    required RepositoryQuery query,
    required String studentId,
  }) =>
      _api.listRecoveryContacts(query: query, studentId: studentId);

  @override
  Future<PromiseToPay> createPromiseToPay({
    required RepositoryQuery query,
    required CreatePromiseToPayRequest request,
  }) =>
      _api.createPromiseToPay(query: query, request: request);

  @override
  Future<List<PromiseToPay>> listPromisesToPay({
    required RepositoryQuery query,
    PromiseToPayStatus? status,
  }) =>
      _api.listPromisesToPay(query: query, status: status);

  @override
  Future<PromiseToPay> resolvePromiseToPay({
    required RepositoryQuery query,
    required String promiseId,
    required ResolvePromiseToPayRequest request,
  }) =>
      _api.resolvePromiseToPay(
        query: query,
        promiseId: promiseId,
        request: request,
      );

  @override
  Future<RecoveryDashboardData> getRecoveryDashboard({
    required RepositoryQuery query,
  }) =>
      _api.getRecoveryDashboard(query: query);
}
