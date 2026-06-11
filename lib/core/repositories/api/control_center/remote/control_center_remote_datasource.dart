import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../dto/control_center_responses_dto.dart';
import 'control_center_api_paths.dart';

/// Dio-backed remote data source for Control Center.
class ControlCenterRemoteDataSource {
  ControlCenterRemoteDataSource(this._dio);

  final Dio _dio;

  Future<ControlCenterDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return ControlCenterDashboardDto.fromJson(_responseMap(response));
  }

  Future<PlatformSchoolsResponseDto> fetchSchools({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.schools,
      queryParameters: _queryParams(query),
    );
    return PlatformSchoolsResponseDto.fromJson(_responseMap(response));
  }

  Future<ControlCenterSubscriptionsResponseDto> fetchSubscriptions({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.subscriptions,
      queryParameters: _queryParams(query),
    );
    return ControlCenterSubscriptionsResponseDto.fromJson(_responseMap(response));
  }

  Future<ControlCenterBillingResponseDto> fetchBilling({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.billing,
      queryParameters: _queryParams(query),
    );
    return ControlCenterBillingResponseDto.fromJson(_responseMap(response));
  }

  Future<ControlCenterCrmResponseDto> fetchCrmPipeline({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.crmPipeline,
      queryParameters: _queryParams(query),
    );
    return ControlCenterCrmResponseDto.fromJson(_responseMap(response));
  }

  Future<SupportTicketsResponseDto> fetchSupportTickets({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.supportTickets,
      queryParameters: _queryParams(query),
    );
    return SupportTicketsResponseDto.fromJson(_responseMap(response));
  }

  Future<ControlCenterSuccessResponseDto> fetchCustomerSuccess({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.customerSuccess,
      queryParameters: _queryParams(query),
    );
    return ControlCenterSuccessResponseDto.fromJson(_responseMap(response));
  }

  Future<WhiteLabelConfigsResponseDto> fetchWhiteLabelConfigs({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.whiteLabel,
      queryParameters: _queryParams(query),
    );
    return WhiteLabelConfigsResponseDto.fromJson(_responseMap(response));
  }

  Future<ControlCenterAnalyticsResponseDto> fetchAnalytics({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.analytics,
      queryParameters: _queryParams(query),
    );
    return ControlCenterAnalyticsResponseDto.fromJson(_responseMap(response));
  }

  Future<ControlCenterMonitoringResponseDto> fetchMonitoring({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.monitoring,
      queryParameters: _queryParams(query),
    );
    return ControlCenterMonitoringResponseDto.fromJson(_responseMap(response));
  }

  Future<ControlCenterRolesResponseDto> fetchRoles({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.roles,
      queryParameters: _queryParams(query),
    );
    return ControlCenterRolesResponseDto.fromJson(_responseMap(response));
  }

  Future<ControlCenterSettingsResponseDto> fetchSettings({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.settings,
      queryParameters: _queryParams(query),
    );
    return ControlCenterSettingsResponseDto.fromJson(_responseMap(response));
  }

  Future<Map<String, dynamic>> fetchProvidersRaw({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.providers,
      queryParameters: _queryParams(query),
    );
    return ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();
  }

  Future<Map<String, dynamic>> fetchUsageRaw({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.usage,
      queryParameters: _queryParams(query),
    );
    return ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();
  }

  Future<List<Map<String, dynamic>>> fetchFeaturesRaw({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ControlCenterApiPaths.features,
      queryParameters: _queryParams(query),
    );
    return ApiEnvelopeDto.fromJson(response.data ?? const {}).requireListItems();
  }

  Future<void> upsertProviderRaw({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    await _dio.post<void>(
      ControlCenterApiPaths.providers,
      queryParameters: _queryParams(query),
      data: body,
    );
  }

  Future<void> setFeatureRaw({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    await _dio.post<void>(
      ControlCenterApiPaths.features,
      queryParameters: _queryParams(query),
      data: body,
    );
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
    };
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }
}
