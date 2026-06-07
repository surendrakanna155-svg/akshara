import '../../interfaces/finance_repository.dart';
import '../../pagination_helpers.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/finance/finance_models.dart';
import '../../../../features/finance/finance_requests.dart';
import 'mapper/finance_mapper.dart';
import 'remote/finance_remote_datasource.dart';

/// API implementation of [FinanceRepository] — enabled via [financeApiEnabledProvider].
class ApiFinanceRepository implements FinanceRepository {
  ApiFinanceRepository({
    required FinanceRemoteDataSource remote,
    FinanceMapper mapper = const FinanceMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final FinanceRemoteDataSource _remote;
  final FinanceMapper _mapper;

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
    final dto = await _remote.fetchAcademicYears(query: query);
    return paginateList(_mapper.toAcademicYears(dto), query);
  }

  @override
  Future<PaginatedResult<StudentFeeAccount>> getStudentAccounts({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchStudentAccounts(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toStudentAccounts(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<PaginatedResult<InstallmentPlan>> getInstallmentPlans({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchFeeAssignment(query: query);
    return paginateList(_mapper.toInstallmentPlans(dto), query);
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
}
