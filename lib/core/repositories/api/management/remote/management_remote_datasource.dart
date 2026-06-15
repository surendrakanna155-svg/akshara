import 'package:dio/dio.dart';

import '../../../../../features/management/management_requests.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../../../repository_query.dart';
import '../dto/management_responses_dto.dart';
import '../dto/update_management_settings_request_dto.dart';
import 'management_api_paths.dart';

/// Dio-backed remote data source for Management.
class ManagementRemoteDataSource {
  ManagementRemoteDataSource(this._dio);

  final Dio _dio;

  Future<ManagementDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ManagementApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return ManagementDashboardDto.fromJson(_responseMap(response));
  }

  Future<ManagementAnalyticsResponseDto> fetchAnalytics({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ManagementApiPaths.analytics,
      queryParameters: _queryParams(query),
    );
    return ManagementAnalyticsResponseDto.fromJson(_responseMap(response));
  }

  Future<ManagementAdmissionsFunnelResponseDto> fetchAdmissionsFunnel({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ManagementApiPaths.admissionsFunnel,
      queryParameters: _queryParams(query),
    );
    return ManagementAdmissionsFunnelResponseDto.fromJson(
        _responseMap(response));
  }

  Future<ManagementFinancialHealthResponseDto> fetchFinancialHealth({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ManagementApiPaths.financialHealth,
      queryParameters: _queryParams(query),
    );
    return ManagementFinancialHealthResponseDto.fromJson(
        _responseMap(response));
  }

  Future<ManagementAcademicHealthResponseDto> fetchAcademicHealth({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ManagementApiPaths.academicHealth,
      queryParameters: _queryParams(query),
    );
    return ManagementAcademicHealthResponseDto.fromJson(_responseMap(response));
  }

  Future<ManagementPerformanceResponseDto> fetchSchoolPerformance({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ManagementApiPaths.schoolPerformance,
      queryParameters: _queryParams(query),
    );
    return ManagementPerformanceResponseDto.fromJson(_responseMap(response));
  }

  Future<ManagementTasksResponseDto> fetchTasksAndApprovals({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ManagementApiPaths.tasks,
      queryParameters: _queryParams(query),
    );
    return ManagementTasksResponseDto.fromJson(_responseMap(response));
  }

  Future<ManagementSettingsResponseDto> fetchSettings({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ManagementApiPaths.settings,
      queryParameters: _queryParams(query),
    );
    return ManagementSettingsResponseDto.fromJson(_responseMap(response));
  }

  Future<ManagementSettingsResponseDto> updateSettings({
    required RepositoryQuery query,
    required UpdateManagementSettingsRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ManagementApiPaths.settings,
      queryParameters: _queryParams(query),
      data: UpdateManagementSettingsRequestDto.fromDomain(request).toJson(),
    );
    return ManagementSettingsResponseDto.fromJson(_responseMap(response));
  }

  Future<ManagementApprovalResponseDto> resolveApproval({
    required RepositoryQuery query,
    required String approvalId,
    required String status,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ManagementApiPaths.approvalResolve(approvalId),
      queryParameters: _queryParams(query),
      data: {'status': status},
    );
    final envelope = ApiEnvelopeDto.fromJson(_responseMap(response));
    return ManagementApprovalResponseDto(raw: envelope.requireData());
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
}
