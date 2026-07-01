import 'package:dio/dio.dart';

import '../../../../../features/finance/finance_models.dart';
import '../../../../../features/finance/finance_requests.dart';
import '../../../../reliability/model/mutation_outcome.dart';
import '../../../../reliability/policy/operation_policy_registry.dart';
import '../../../../reliability/reliable_datasource_write.dart';
import '../../../../reliability/reliable_writer.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../../../repository_query.dart';
import '../dto/approve_refund_request_dto.dart';
import '../dto/assign_fee_plan_request_dto.dart';
import '../dto/confirm_qr_payment_request_dto.dart';
import '../dto/create_fee_structure_request_dto.dart';
import '../dto/create_refund_request_dto.dart';
import '../dto/create_scholarship_request_dto.dart';
import '../dto/create_discount_rule_request_dto.dart';
import '../dto/create_collection_request_dto.dart';
import '../dto/create_qr_payment_session_request_dto.dart';
import '../dto/finance_d_features_dto.dart';
import '../dto/finance_collections_dto.dart';
import '../dto/finance_dashboard_dto.dart';
import '../dto/finance_defaulters_dto.dart';
import '../dto/finance_discounts_dto.dart';
import '../dto/finance_fee_structures_dto.dart';
import '../dto/finance_enum_codec.dart';
import '../dto/finance_invoices_dto.dart';
import '../dto/finance_receipt_dto.dart';
import '../dto/finance_recovery_dto.dart';
import '../dto/finance_refunds_dto.dart';
import '../dto/finance_reports_dto.dart';
import '../dto/finance_settings_dto.dart';
import '../dto/finance_student_accounts_dto.dart';
import '../dto/offline_payment_dto.dart';
import '../dto/reconcile_offline_payment_request_dto.dart';
import '../dto/record_offline_payment_request_dto.dart';
import '../dto/scholarship_dto.dart';
import '../dto/qr_payment_session_dto.dart';
import '../dto/update_fee_structure_request_dto.dart';
import '../dto/update_finance_settings_request_dto.dart';
import '../dto/update_scholarship_request_dto.dart';
import '../dto/update_discount_rule_request_dto.dart';
import '../dto/update_student_account_request_dto.dart';
import '../mapper/finance_mapper.dart';
import 'finance_api_paths.dart';

/// Dio-backed remote data source for Finance.
///
/// Fee collection routes through the Data Reliability Platform's
/// [ReliableWriter] when one is injected: the write is queued offline and
/// replayed exactly-once (the backend's idempotency key guarantees no
/// double-charge / double-receipt). While queued it returns a `pendingSync`
/// result so the UI shows "Pending Sync" and never finalises a receipt until the
/// server confirms (refinement R1). Without a writer it falls back to a direct
/// Dio call.
class FinanceRemoteDataSource {
  FinanceRemoteDataSource(
    this._dio, {
    FinanceMapper mapper = const FinanceMapper(),
    ReliableWriter? reliableWriter,
  })  : _mapper = mapper,
        _reliable = reliableWriter;

  final Dio _dio;
  final FinanceMapper _mapper;
  final ReliableWriter? _reliable;

  Future<FinanceDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return FinanceDashboardDto.fromJson(_responseMap(response));
  }

  Future<FinanceCollectionsResponseDto> fetchCollections({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.collections,
      queryParameters: _queryParams(query),
    );
    return FinanceCollectionsResponseDto.fromJson(_responseMap(response));
  }

  Future<DailyCollectionSummaryDto> fetchDailySummary({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.dailySummary,
      queryParameters: _queryParams(query),
    );
    return DailyCollectionSummaryDto.fromJson(_responseMap(response));
  }

  Future<FinanceFeeStructuresResponseDto> fetchFeeStructures({
    required RepositoryQuery query,
    required String academicYear,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.feeStructures,
      queryParameters: {
        ..._queryParams(query),
        'academicYear': academicYear,
      },
    );
    return FinanceFeeStructuresResponseDto.fromJson(_responseMap(response));
  }

  Future<FinanceFeeAssignmentsResponseDto> fetchFeeAssignments({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.feeAssignments,
      queryParameters: _queryParams(query),
    );
    return FinanceFeeAssignmentsResponseDto.fromJson(_responseMap(response));
  }

  Future<StudentFeeAccountDto> fetchStudentAccount({
    required RepositoryQuery query,
    required String studentId,
    String? academicYear,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.studentAccount(studentId),
      queryParameters: {
        ..._queryParams(query),
        if (academicYear != null && academicYear.isNotEmpty)
          'academicYear': academicYear,
      },
    );
    return StudentFeeAccountDto.fromJson(_requireData(response));
  }

  Future<FinanceReceiptResponseDto> fetchReceipt({
    required RepositoryQuery query,
    required String receiptId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.receipt(receiptId),
      queryParameters: _queryParams(query),
    );
    return FinanceReceiptResponseDto.fromJson(_responseMap(response));
  }

  Future<CollectionDetailDto> fetchCollectionDetail({
    required RepositoryQuery query,
    required String collectionId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.collectionDetail(collectionId),
      queryParameters: _queryParams(query),
    );
    return CollectionDetailDto.fromJson(_responseMap(response));
  }

  Future<FinanceCollectionResultDto> createCollection({
    required RepositoryQuery query,
    required CreateCollectionRequest request,
  }) async {
    final Map<String, dynamic> body =
        CreateCollectionRequestDto.fromDomain(request).toJson();
    final ReliableWriter? reliable = _reliable;
    if (reliable == null) {
      final response = await _dio.post<Map<String, dynamic>>(
        FinanceApiPaths.collections,
        queryParameters: _queryParams(query),
        data: body,
      );
      return FinanceCollectionResultDto.fromJson(_requireData(response));
    }
    final MutationOutcome outcome = await reliable.runWrite(
      type: OperationTypes.collectFee,
      method: 'POST',
      path: FinanceApiPaths.collections,
      body: body,
      scope: _queryParams(query),
      entityRef: 'fee:${request.invoiceId}',
    );
    final ResolvedWrite resolved = resolveWriteOutcome(
      outcome,
      // Offline-queued money: NO receipt number is minted client-side. The
      // optimistic projection is explicitly non-final (pendingSync) so the UI
      // shows "Pending Sync" and a receipt is generated only after the server
      // confirms the transaction (refinement R1).
      optimistic: () => <String, dynamic>{
        'pendingSync': true,
        'collection': <String, dynamic>{
          'invoiceId': request.invoiceId,
          'amountCollected': request.amountCollected,
          'paymentMethod': request.paymentMethod,
          'collectionDate': request.collectionDate ?? 'Today',
        },
        'receipt': const <String, dynamic>{},
        'invoice': const <String, dynamic>{},
      },
    );
    return FinanceCollectionResultDto.fromJson(resolved.data);
  }

  Future<QrPaymentSessionDto> createQrPaymentSession({
    required RepositoryQuery query,
    required CreateQrPaymentSessionRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.qrPayments,
      queryParameters: _queryParams(query),
      data: CreateQrPaymentSessionRequestDto.fromDomain(request).toJson(),
    );
    return QrPaymentSessionDto.fromJson(_requireData(response));
  }

  Future<QrPaymentSessionDto> fetchQrPaymentSession({
    required RepositoryQuery query,
    required String sessionId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.qrPaymentSession(sessionId),
      queryParameters: _queryParams(query),
    );
    return QrPaymentSessionDto.fromJson(_requireData(response));
  }

  Future<QrPaymentSessionDto> confirmQrPaymentSession({
    required RepositoryQuery query,
    required String sessionId,
    required ConfirmQrPaymentRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.qrPaymentConfirm(sessionId),
      queryParameters: _queryParams(query),
      data: ConfirmQrPaymentRequestDto.fromDomain(request).toJson(),
    );
    return QrPaymentSessionDto.fromJson(_requireData(response));
  }

  Future<FinanceCollectionResultDto> cancelCollection({
    required RepositoryQuery query,
    required String collectionId,
    required String reason,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.collectionCancel(collectionId),
      queryParameters: _queryParams(query),
      // FIN-D3: the mandatory cancellation reason travels in the body.
      data: {'reason': reason},
    );
    return FinanceCollectionResultDto.fromJson(_requireData(response));
  }

  // ── FIN-D3: cancelled register ─────────────────────────────────────────────
  Future<CancelledCollectionsResponseDto> fetchCancelledCollections({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.collectionsCancelled,
      queryParameters: _queryParams(query),
    );
    return CancelledCollectionsResponseDto.fromJson(_responseMap(response));
  }

  // ── FIN-6: invoice installment schedule ────────────────────────────────────
  Future<InstallmentScheduleResponseDto> fetchInvoiceInstallments({
    required RepositoryQuery query,
    required String invoiceId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.invoiceInstallments(invoiceId),
      queryParameters: _queryParams(query),
    );
    return InstallmentScheduleResponseDto.fromJson(_responseMap(response));
  }

  // ── FIN-9: head-wise dues analytics ────────────────────────────────────────
  Future<HeadWiseDuesResponseDto> fetchHeadWiseDues({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.analyticsHeadWiseDues,
      queryParameters: _queryParams(query),
    );
    return HeadWiseDuesResponseDto.fromJson(_responseMap(response));
  }

  // ── FIN-D5: late-fee accrual + waive ───────────────────────────────────────
  Future<LateFeeAccrualResultDto> accrueLateFees({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.lateFeesAccrue,
      queryParameters: _queryParams(query),
    );
    return LateFeeAccrualResultDto.fromJson(_responseMap(response));
  }

  Future<FinanceInvoiceDto> waiveLateFee({
    required RepositoryQuery query,
    required String invoiceId,
    required String reason,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.invoiceWaiveLateFee(invoiceId),
      queryParameters: _queryParams(query),
      data: {'reason': reason},
    );
    return FinanceInvoiceDto.fromJson(_requireData(response));
  }

  // ── FIN-D1: day-close lock ─────────────────────────────────────────────────
  Future<DayCloseEntriesResponseDto> fetchDayCloseEntries({
    required RepositoryQuery query,
    String? from,
    String? to,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.dayClose,
      queryParameters: {
        ..._queryParams(query),
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    return DayCloseEntriesResponseDto.fromJson(_responseMap(response));
  }

  Future<DayCloseEntryDto> closeDay({
    required RepositoryQuery query,
    String? date,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.dayClose,
      queryParameters: _queryParams(query),
      data: {if (date != null && date.isNotEmpty) 'close_date': date},
    );
    return DayCloseEntryDto.fromJson(_requireData(response));
  }

  Future<DayCloseEntryDto> reopenDay({
    required RepositoryQuery query,
    required String date,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.dayCloseReopen(date),
      queryParameters: _queryParams(query),
    );
    return DayCloseEntryDto.fromJson(_requireData(response));
  }

  // ── FIN-2: printable student ledger ────────────────────────────────────────
  Future<StudentLedgerDto> fetchStudentLedger({
    required RepositoryQuery query,
    required String studentAccountId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.studentLedger(studentAccountId),
      queryParameters: _queryParams(query),
    );
    return StudentLedgerDto.fromJson(_responseMap(response));
  }

  Future<OfflinePaymentDto> recordOfflinePayment({
    required RepositoryQuery query,
    required RecordOfflinePaymentRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.offlinePayments,
      queryParameters: _queryParams(query),
      data: RecordOfflinePaymentRequestDto.fromDomain(request).toJson(),
    );
    return OfflinePaymentDto.fromJson(_requireData(response));
  }

  Future<OfflinePaymentsResponseDto> fetchOfflinePayments({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.offlinePayments,
      queryParameters: _queryParams(query),
    );
    return OfflinePaymentsResponseDto.fromJson(_responseMap(response));
  }

  Future<OfflinePaymentDto> reconcileOfflinePayment({
    required RepositoryQuery query,
    required String offlinePaymentId,
    required ReconcileOfflinePaymentRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.offlinePaymentReconcile(offlinePaymentId),
      queryParameters: _queryParams(query),
      data: ReconcileOfflinePaymentRequestDto.fromDomain(request).toJson(),
    );
    return OfflinePaymentDto.fromJson(_requireData(response));
  }

  Future<DefaultersDashboardDto> fetchDefaultersDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.defaulters,
      queryParameters: _queryParams(query),
    );
    return DefaultersDashboardDto.fromJson(_responseMap(response));
  }

  Future<RefundRequestsResponseDto> fetchRefundRequests({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.refunds,
      queryParameters: _queryParams(query),
    );
    return RefundRequestsResponseDto.fromJson(_responseMap(response));
  }

  Future<RefundRequestDto> fetchRefund({
    required RepositoryQuery query,
    required String refundId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.refund(refundId),
      queryParameters: _queryParams(query),
    );
    return RefundRequestDto.fromJson(_requireData(response));
  }

  Future<DiscountsDashboardDto> fetchDiscountsDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.discounts,
      queryParameters: _queryParams(query),
    );
    return DiscountsDashboardDto.fromJson(_responseMap(response));
  }

  Future<FinanceReportsDto> fetchReports({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.reports,
      queryParameters: _queryParams(query),
    );
    return FinanceReportsDto.fromJson(_responseMap(response));
  }

  Future<FinanceSettingsDto> fetchSettings({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.settings,
      queryParameters: _queryParams(query),
    );
    return FinanceSettingsDto.fromJson(_responseMap(response));
  }

  Future<FinanceFeeStructure> createFeeStructure({
    required RepositoryQuery query,
    required CreateFeeStructureRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.feeStructures,
      queryParameters: _queryParams(query),
      data: CreateFeeStructureRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toFeeStructure(
      FinanceFeeStructureDto.fromJson(_requireData(response)),
    );
  }

  Future<FinanceFeeStructure> updateFeeStructure({
    required RepositoryQuery query,
    required String feeStructureId,
    required UpdateFeeStructureRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      FinanceApiPaths.feeStructure(feeStructureId),
      queryParameters: _queryParams(query),
      data: UpdateFeeStructureRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toFeeStructure(
      FinanceFeeStructureDto.fromJson(_requireData(response)),
    );
  }

  Future<StudentFeeAccount> createStudentAccount({
    required RepositoryQuery query,
    required CreateStudentAccountRequest request,
  }) async {
    throw UnsupportedError(
      'createStudentAccount is not available in API mode; use assignFeePlan',
    );
  }

  Future<StudentFeeAccount> updateStudentAccount({
    required RepositoryQuery query,
    required String accountId,
    required UpdateStudentAccountRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      FinanceApiPaths.studentAccount(accountId),
      queryParameters: _queryParams(query),
      data: UpdateStudentAccountRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toStudentAccount(
      StudentFeeAccountDto.fromJson(_requireData(response)),
    );
  }

  Future<StudentFeeAccount> assignFeePlan({
    required RepositoryQuery query,
    required AssignFeePlanRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.feeAssignmentAssign,
      queryParameters: _queryParams(query),
      data: AssignFeePlanRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toStudentAccount(
      StudentFeeAccountDto.fromJson(_requireData(response)),
    );
  }

  Future<RefundRequest> createRefund({
    required RepositoryQuery query,
    required CreateRefundRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.refunds,
      queryParameters: _queryParams(query),
      data: CreateRefundRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toRefundRequest(
      RefundRequestDto.fromJson(_requireData(response)),
    );
  }

  Future<RefundRequest> approveRefund({
    required RepositoryQuery query,
    required String refundId,
    ApproveRefundRequest request = const ApproveRefundRequest(),
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.refundApprove(refundId),
      queryParameters: _queryParams(query),
      data: ApproveRefundRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toRefundRequest(
      RefundRequestDto.fromJson(_requireData(response)),
    );
  }

  Future<RefundRequest> rejectRefund({
    required RepositoryQuery query,
    required String refundId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.refundReject(refundId),
      queryParameters: _queryParams(query),
    );
    return _mapper.toRefundRequest(
      RefundRequestDto.fromJson(_requireData(response)),
    );
  }

  Future<ScholarshipCatalogItem> createScholarship({
    required RepositoryQuery query,
    required CreateScholarshipRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.scholarships,
      queryParameters: _queryParams(query),
      data: CreateScholarshipRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toScholarship(
      ScholarshipDto.fromJson(_requireData(response)),
    );
  }

  Future<ScholarshipCatalogItem> updateScholarship({
    required RepositoryQuery query,
    required String scholarshipId,
    required UpdateScholarshipRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      FinanceApiPaths.scholarship(scholarshipId),
      queryParameters: _queryParams(query),
      data: UpdateScholarshipRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toScholarship(
      ScholarshipDto.fromJson(_requireData(response)),
    );
  }

  Future<DiscountRule> createDiscountRule({
    required RepositoryQuery query,
    required CreateDiscountRuleRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.discounts,
      queryParameters: _queryParams(query),
      data: CreateDiscountRuleRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toDiscountRule(
      DiscountRuleDto.fromJson(_requireData(response)),
    );
  }

  Future<DiscountRule> updateDiscountRule({
    required RepositoryQuery query,
    required String ruleId,
    required UpdateDiscountRuleRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      FinanceApiPaths.discount(ruleId),
      queryParameters: _queryParams(query),
      data: UpdateDiscountRuleRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toDiscountRule(
      DiscountRuleDto.fromJson(_requireData(response)),
    );
  }

  Future<FinanceSettingsData> updateSettings({
    required RepositoryQuery query,
    required UpdateFinanceSettingsRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      FinanceApiPaths.settings,
      queryParameters: _queryParams(query),
      data: UpdateFinanceSettingsRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toSettings(
      FinanceSettingsDto.fromJson(_responseMap(response)),
    );
  }

  Future<FinanceInvoicesResponseDto> fetchInvoices({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.invoices,
      queryParameters: _queryParams(query),
    );
    return FinanceInvoicesResponseDto.fromJson(_responseMap(response));
  }

  Future<FinanceInvoiceDto> fetchInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.invoice(invoiceId),
      queryParameters: _queryParams(query),
    );
    return FinanceInvoiceDto.fromJson(_requireData(response));
  }

  Future<FinanceInvoiceDto> issueInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.invoiceIssue(invoiceId),
      queryParameters: _queryParams(query),
    );
    return FinanceInvoiceDto.fromJson(_requireData(response));
  }

  Future<FinanceInvoiceDto> cancelInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.invoiceCancel(invoiceId),
      queryParameters: _queryParams(query),
    );
    return FinanceInvoiceDto.fromJson(_requireData(response));
  }

  // ── FIN-R1..R5: fee-recovery CRM ───────────────────────────────────────────
  Future<RecoveryContactDto> logRecoveryContact({
    required RepositoryQuery query,
    required LogRecoveryContactRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.recoveryContacts,
      queryParameters: _queryParams(query),
      data: {
        'studentId': request.studentId,
        if (request.feeAccountId != null && request.feeAccountId!.isNotEmpty)
          'feeAccountId': request.feeAccountId,
        'channel': FinanceEnumCodec.recoveryChannelToApi(request.channel),
        'outcome': FinanceEnumCodec.recoveryOutcomeToApi(request.outcome),
        'notes': request.notes,
      },
    );
    return RecoveryContactDto.fromJson(_requireData(response));
  }

  Future<RecoveryContactsResponseDto> fetchRecoveryContacts({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.recoveryContactsForStudent(studentId),
      queryParameters: _queryParams(query),
    );
    return RecoveryContactsResponseDto.fromJson(_responseMap(response));
  }

  Future<PromiseToPayDto> createPromiseToPay({
    required RepositoryQuery query,
    required CreatePromiseToPayRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.recoveryPromises,
      queryParameters: _queryParams(query),
      data: {
        'studentId': request.studentId,
        if (request.feeAccountId != null && request.feeAccountId!.isNotEmpty)
          'feeAccountId': request.feeAccountId,
        'amount': request.amount,
        'promiseDate': request.promiseDate,
        'notes': request.notes,
      },
    );
    return PromiseToPayDto.fromJson(_requireData(response));
  }

  Future<PromisesToPayResponseDto> fetchPromisesToPay({
    required RepositoryQuery query,
    PromiseToPayStatus? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.recoveryPromises,
      queryParameters: {
        ..._queryParams(query),
        if (status != null)
          'status': FinanceEnumCodec.promiseToPayStatusToApi(status),
      },
    );
    return PromisesToPayResponseDto.fromJson(_responseMap(response));
  }

  Future<PromiseToPayDto> resolvePromiseToPay({
    required RepositoryQuery query,
    required String promiseId,
    required ResolvePromiseToPayRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.recoveryPromiseResolve(promiseId),
      queryParameters: _queryParams(query),
      data: {
        'status': FinanceEnumCodec.promiseToPayStatusToApi(request.status),
      },
    );
    return PromiseToPayDto.fromJson(_requireData(response));
  }

  Future<RecoveryDashboardDto> fetchRecoveryDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.recoveryDashboard,
      queryParameters: _queryParams(query),
    );
    return RecoveryDashboardDto.fromJson(_responseMap(response));
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
      ...query.paginationQueryParams(),
    };
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(_responseMap(response)).requireData();
  }

  Future<Map<String, dynamic>> fetchFinanceCopilot(
      {required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.intelligenceCopilot,
      queryParameters: _queryParams(query),
    );
    return _requireData(response);
  }

  Future<Map<String, dynamic>> fetchFinanceExecutive(
      {required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.intelligenceExecutive,
      queryParameters: _queryParams(query),
    );
    return _requireData(response);
  }
}
