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
import '../dto/create_collection_request_dto.dart';
import '../dto/finance_collections_dto.dart';
import '../dto/finance_dashboard_dto.dart';
import '../dto/finance_defaulters_dto.dart';
import '../dto/finance_discounts_dto.dart';
import '../dto/finance_fee_structures_dto.dart';
import '../dto/finance_invoices_dto.dart';
import '../dto/finance_receipt_dto.dart';
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
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.collections,
      queryParameters: _queryParams(query),
      data: CreateCollectionRequestDto.fromDomain(request).toJson(),
    );
    return FinanceCollectionResultDto.fromJson(_requireData(response));
  }

  Future<FinanceCollectionResultDto> cancelCollection({
    required RepositoryQuery query,
    required String collectionId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      FinanceApiPaths.collectionCancel(collectionId),
      queryParameters: _queryParams(query),
    );
    return FinanceCollectionResultDto.fromJson(_requireData(response));
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

  Future<Map<String, dynamic>> fetchFinanceCopilot({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.intelligenceCopilot,
      queryParameters: _queryParams(query),
    );
    return _requireData(response);
  }

  Future<Map<String, dynamic>> fetchFinanceExecutive({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FinanceApiPaths.intelligenceExecutive,
      queryParameters: _queryParams(query),
    );
    return _requireData(response);
  }
}
