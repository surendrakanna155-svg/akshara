import 'package:dio/dio.dart';

import '../../../../../features/finance/finance_models.dart';
import '../../../../../features/finance/finance_requests.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../../../repository_query.dart';
import '../dto/approve_refund_request_dto.dart';
import '../dto/assign_fee_plan_request_dto.dart';
import '../dto/create_fee_structure_request_dto.dart';
import '../dto/create_refund_request_dto.dart';
import '../dto/create_scholarship_request_dto.dart';
import '../dto/create_student_account_request_dto.dart';
import '../dto/finance_collections_dto.dart';
import '../dto/finance_dashboard_dto.dart';
import '../dto/finance_defaulters_dto.dart';
import '../dto/finance_discounts_dto.dart';
import '../dto/finance_fee_structures_dto.dart';
import '../dto/finance_refunds_dto.dart';
import '../dto/finance_reports_dto.dart';
import '../dto/finance_settings_dto.dart';
import '../dto/finance_student_accounts_dto.dart';
import '../dto/scholarship_dto.dart';
import '../dto/update_fee_structure_request_dto.dart';
import '../dto/update_finance_settings_request_dto.dart';
import '../dto/update_scholarship_request_dto.dart';
import '../dto/update_student_account_request_dto.dart';
import '../mapper/finance_mapper.dart';
import 'finance_api_paths.dart';

/// Dio-backed remote data source for Finance.
class FinanceRemoteDataSource {
  FinanceRemoteDataSource(
    this._dio, {
    FinanceMapper mapper = const FinanceMapper(),
  }) : _mapper = mapper;

  final Dio _dio;
  final FinanceMapper _mapper;

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

  Future<FinanceAcademicYearsResponseDto> fetchAcademicYears({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.academicYears,
      queryParameters: _queryParams(query),
    );
    return FinanceAcademicYearsResponseDto.fromJson(_responseMap(response));
  }

  Future<StudentFeeAccountsResponseDto> fetchStudentAccounts({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.studentAccounts,
      queryParameters: _queryParams(query),
    );
    return StudentFeeAccountsResponseDto.fromJson(_responseMap(response));
  }

  Future<FinanceFeeAssignmentResponseDto> fetchFeeAssignment({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.feeAssignment,
      queryParameters: _queryParams(query),
    );
    return FinanceFeeAssignmentResponseDto.fromJson(_responseMap(response));
  }

  /// @deprecated Use [fetchFeeAssignment].
  Future<InstallmentPlansResponseDto> fetchInstallmentPlans({
    required RepositoryQuery query,
  }) => fetchFeeAssignment(query: query);

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
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.studentAccounts,
      queryParameters: _queryParams(query),
      data: CreateStudentAccountRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toStudentAccount(
      StudentFeeAccountDto.fromJson(_requireData(response)),
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
    final response = await _dio.patch<Map<String, dynamic>>(
      FinanceApiPaths.refundApprove(refundId),
      queryParameters: _queryParams(query),
      data: ApproveRefundRequestDto.fromDomain(request).toJson(),
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
}
