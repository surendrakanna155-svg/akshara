import '../../interfaces/finance_repository.dart';
import '../../pagination_helpers.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/finance/finance_models.dart';
import '../../../../features/finance/finance_requests.dart';
import '../../../../features/finance/intelligence/finance_intelligence_models.dart';
import 'finance_installment_plan_catalog.dart';
import 'mapper/finance_mapper.dart';
import 'mapper/finance_intelligence_mapper.dart';
import 'remote/finance_remote_datasource.dart';

/// API implementation of [FinanceRepository] — enabled via [financeApiEnabledProvider].
class ApiFinanceRepository implements FinanceRepository {
  ApiFinanceRepository({
    required FinanceRemoteDataSource remote,
    FinanceMapper mapper = const FinanceMapper(),
    FinanceIntelligenceMapper intelligenceMapper =
        const FinanceIntelligenceMapper(),
  })  : _remote = remote,
        _mapper = mapper,
        _intelligenceMapper = intelligenceMapper;

  final FinanceRemoteDataSource _remote;
  final FinanceMapper _mapper;
  final FinanceIntelligenceMapper _intelligenceMapper;

  @override
  Future<FinanceDashboardData> getDashboard({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<PaginatedResult<CollectionPayment>> getCollections({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchCollections(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toCollections(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<DailyCollectionSummary> getDailySummary({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchDailySummary(query: query);
    return _mapper.toDailySummary(dto);
  }

  @override
  Future<PaginatedResult<FinanceFeeStructure>> getFeeStructures({
    required RepositoryQuery query,
    required String academicYear,
  }) async {
    final dto = await _remote.fetchFeeStructures(
      query: query,
      academicYear: academicYear,
    );
    return paginateList(_mapper.toFeeStructures(dto), query);
  }

  @override
  Future<PaginatedResult<String>> getAcademicYears({
    required RepositoryQuery query,
  }) async {
    final structures = await _remote.fetchFeeStructures(
      query: query,
      academicYear: '',
    );
    final years = _mapper
        .toFeeStructures(structures)
        .map((structure) => structure.academicYear)
        .where((year) => year.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    return paginateList(years, query);
  }

  @override
  Future<PaginatedResult<StudentFeeAccount>> getStudentAccounts({
    required RepositoryQuery query,
  }) async {
    final assignments = await _remote.fetchFeeAssignments(query: query);
    final accounts = <StudentFeeAccount>[];
    for (final assignment in assignments.items) {
      final raw = assignment.raw;
      final studentId = raw['studentId'] as String? ?? '';
      final academicYear = raw['academicYear'] as String? ?? '';
      if (studentId.isEmpty) continue;
      if (raw['assignmentStatus'] == 'cancelled') continue;
      try {
        final accountDto = await _remote.fetchStudentAccount(
          query: query,
          studentId: studentId,
          academicYear: academicYear,
        );
        accounts.add(_mapper.toStudentAccount(accountDto));
      } on Object {
        continue;
      }
    }
    return PaginatedResult.fromDto(
      items: accounts,
      pagination: assignments.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<PaginatedResult<InstallmentPlan>> getInstallmentPlans({
    required RepositoryQuery query,
  }) async {
    return paginateList(kFinanceInstallmentPlanCatalog, query);
  }

  @override
  Future<CollectionDetail?> getCollectionDetail({
    required RepositoryQuery query,
    required String collectionId,
  }) async {
    final dto = await _remote.fetchCollectionDetail(
      query: query,
      collectionId: collectionId,
    );
    return _mapper.toCollectionDetail(dto);
  }

  @override
  Future<FinanceCollectionResult> createCollection({
    required RepositoryQuery query,
    required CreateCollectionRequest request,
  }) async {
    final dto = await _remote.createCollection(query: query, request: request);
    return _mapper.toCollectionResult(dto);
  }

  @override
  Future<QrPaymentSession> createQrPaymentSession({
    required RepositoryQuery query,
    required CreateQrPaymentSessionRequest request,
  }) async {
    final dto =
        await _remote.createQrPaymentSession(query: query, request: request);
    return _mapper.toQrPaymentSession(dto);
  }

  @override
  Future<QrPaymentSession?> getQrPaymentSession({
    required RepositoryQuery query,
    required String sessionId,
  }) async {
    final dto = await _remote.fetchQrPaymentSession(
      query: query,
      sessionId: sessionId,
    );
    return _mapper.toQrPaymentSession(dto);
  }

  @override
  Future<QrPaymentSession> confirmQrPaymentSession({
    required RepositoryQuery query,
    required String sessionId,
    required ConfirmQrPaymentRequest request,
  }) async {
    final dto = await _remote.confirmQrPaymentSession(
      query: query,
      sessionId: sessionId,
      request: request,
    );
    return _mapper.toQrPaymentSession(dto);
  }

  @override
  Future<FinanceCollectionResult> cancelCollection({
    required RepositoryQuery query,
    required String collectionId,
  }) async {
    final dto = await _remote.cancelCollection(
      query: query,
      collectionId: collectionId,
    );
    return _mapper.toCollectionResult(dto);
  }

  @override
  Future<OfflinePaymentRecord> recordOfflinePayment({
    required RepositoryQuery query,
    required RecordOfflinePaymentRequest request,
  }) async {
    final dto =
        await _remote.recordOfflinePayment(query: query, request: request);
    return _mapper.toOfflinePayment(dto);
  }

  @override
  Future<PaginatedResult<OfflinePaymentRecord>> listOfflinePayments({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchOfflinePayments(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toOfflinePayments(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<OfflinePaymentRecord> reconcileOfflinePayment({
    required RepositoryQuery query,
    required String offlinePaymentId,
    required ReconcileOfflinePaymentRequest request,
  }) async {
    final dto = await _remote.reconcileOfflinePayment(
      query: query,
      offlinePaymentId: offlinePaymentId,
      request: request,
    );
    return _mapper.toOfflinePayment(dto);
  }

  @override
  Future<DefaultersDashboardData> getDefaultersDashboard({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchDefaultersDashboard(query: query);
    return _mapper.toDefaultersDashboard(dto);
  }

  @override
  Future<PaginatedResult<RefundRequest>> getRefundRequests({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchRefundRequests(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toRefundRequests(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<RefundRequest?> getRefund({
    required RepositoryQuery query,
    required String refundId,
  }) async {
    final dto = await _remote.fetchRefund(
      query: query,
      refundId: refundId,
    );
    return _mapper.toRefundRequest(dto);
  }

  @override
  Future<DiscountsDashboardData> getDiscountsDashboard({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchDiscountsDashboard(query: query);
    return _mapper.toDiscountsDashboard(dto);
  }

  @override
  Future<FinanceReportsData> getReportsData({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchReports(query: query);
    return _mapper.toReports(dto);
  }

  @override
  Future<FinanceSettingsData> getSettings({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchSettings(query: query);
    return _mapper.toSettings(dto);
  }

  @override
  Future<FinanceFeeStructure> createFeeStructure({
    required RepositoryQuery query,
    required CreateFeeStructureRequest request,
  }) =>
      _remote.createFeeStructure(query: query, request: request);

  @override
  Future<FinanceFeeStructure> updateFeeStructure({
    required RepositoryQuery query,
    required String feeStructureId,
    required UpdateFeeStructureRequest request,
  }) =>
      _remote.updateFeeStructure(
        query: query,
        feeStructureId: feeStructureId,
        request: request,
      );

  @override
  Future<StudentFeeAccount> createStudentAccount({
    required RepositoryQuery query,
    required CreateStudentAccountRequest request,
  }) =>
      _remote.createStudentAccount(query: query, request: request);

  @override
  Future<StudentFeeAccount> updateStudentAccount({
    required RepositoryQuery query,
    required String accountId,
    required UpdateStudentAccountRequest request,
  }) =>
      _remote.updateStudentAccount(
        query: query,
        accountId: accountId,
        request: request,
      );

  @override
  Future<StudentFeeAccount> assignFeePlan({
    required RepositoryQuery query,
    required AssignFeePlanRequest request,
  }) =>
      _remote.assignFeePlan(query: query, request: request);

  @override
  Future<RefundRequest> createRefund({
    required RepositoryQuery query,
    required CreateRefundRequest request,
  }) =>
      _remote.createRefund(query: query, request: request);

  @override
  Future<RefundRequest> approveRefund({
    required RepositoryQuery query,
    required String refundId,
    ApproveRefundRequest request = const ApproveRefundRequest(),
  }) =>
      _remote.approveRefund(
        query: query,
        refundId: refundId,
        request: request,
      );

  @override
  Future<RefundRequest> rejectRefund({
    required RepositoryQuery query,
    required String refundId,
  }) =>
      _remote.rejectRefund(query: query, refundId: refundId);

  @override
  Future<FinanceReceiptDetail?> getReceipt({
    required RepositoryQuery query,
    required String receiptId,
  }) async {
    final dto = await _remote.fetchReceipt(
      query: query,
      receiptId: receiptId,
    );
    return _mapper.toReceiptDetail(dto);
  }

  @override
  Future<PaginatedResult<FinanceInvoice>> getInvoices({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchInvoices(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toInvoices(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<FinanceInvoice?> getInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  }) async {
    final dto = await _remote.fetchInvoice(
      query: query,
      invoiceId: invoiceId,
    );
    return _mapper.toFinanceInvoice(dto);
  }

  @override
  Future<FinanceInvoice> issueInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  }) async {
    final dto = await _remote.issueInvoice(
      query: query,
      invoiceId: invoiceId,
    );
    return _mapper.toFinanceInvoice(dto);
  }

  @override
  Future<FinanceInvoice> cancelInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  }) async {
    final dto = await _remote.cancelInvoice(
      query: query,
      invoiceId: invoiceId,
    );
    return _mapper.toFinanceInvoice(dto);
  }

  @override
  Future<ScholarshipCatalogItem> createScholarship({
    required RepositoryQuery query,
    required CreateScholarshipRequest request,
  }) =>
      _remote.createScholarship(query: query, request: request);

  @override
  Future<ScholarshipCatalogItem> updateScholarship({
    required RepositoryQuery query,
    required String scholarshipId,
    required UpdateScholarshipRequest request,
  }) =>
      _remote.updateScholarship(
        query: query,
        scholarshipId: scholarshipId,
        request: request,
      );

  @override
  Future<FinanceSettingsData> updateSettings({
    required RepositoryQuery query,
    required UpdateFinanceSettingsRequest request,
  }) =>
      _remote.updateSettings(query: query, request: request);

  @override
  Future<FinanceCopilotData> getFinanceCopilot(
      {required RepositoryQuery query}) async {
    final dto = await _remote.fetchFinanceCopilot(query: query);
    return _intelligenceMapper.toCopilot(dto);
  }

  @override
  Future<FinanceExecutiveData> getFinanceExecutiveDashboard({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchFinanceExecutive(query: query);
    return _intelligenceMapper.toExecutive(dto);
  }
}
