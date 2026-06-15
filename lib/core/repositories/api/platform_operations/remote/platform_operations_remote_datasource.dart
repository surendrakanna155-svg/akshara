import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import 'platform_operations_api_paths.dart';

class PlatformOperationsRemoteDataSource {
  PlatformOperationsRemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) =>
      ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();

  Map<String, dynamic> _params(RepositoryQuery query) => {
        'tenantId': query.tenantId,
        if (query.schoolId != null) 'schoolId': query.schoolId,
        if (query.organizationId != null)
          'organizationId': query.organizationId,
      };

  Future<Map<String, dynamic>> fetchObservabilityDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.observabilityDashboard,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchApplicationHealth({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.applicationHealth,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchErrorDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.errorDashboard,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchWorkflowMonitoring({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.workflowMonitoring,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchAiMonitoring({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.aiMonitoring,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchPlatformMonitoring({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.platformMonitoring,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchSchoolHealthMonitoring({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.schoolHealthMonitoring,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchSystemMetrics({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.systemMetrics,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchAlertDefinitions({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.alertDefinitions,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchActiveAlerts({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.activeAlerts,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchAlertHistory({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.alertHistory,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> acknowledgeAlert({
    required RepositoryQuery query,
    required String alertId,
    String? note,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      PlatformOperationsApiPaths.acknowledgeAlert(alertId),
      queryParameters: _params(query),
      data: {if (note != null) 'note': note},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchTenantIsolationDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.tenantIsolation,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> runTenantVerification({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      PlatformOperationsApiPaths.tenantVerification,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchTenantDiagnostics({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.tenantDiagnostics,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchSecurityDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.securityDashboard,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchPermissionAuditSummary({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.permissionAudit,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchRoleAuditSummary({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.roleAudit,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchMutationAudits({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.mutationAudits,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchPrivilegedActions({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.privilegedActions,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchAccessReviews({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.accessReviews,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> completeAccessReview({
    required RepositoryQuery query,
    required String reviewId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      PlatformOperationsApiPaths.completeAccessReview(reviewId),
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchSecurityRecommendations({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.securityRecommendations,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchProductionReadinessReport({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.productionReadiness,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchErrorIntelligence({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.errorIntelligence,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchErrorRecommendations({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.errorRecommendations,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchPlatformHealthIntelligence({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformOperationsApiPaths.platformHealthIntelligence,
      queryParameters: _params(query),
    );
    return _data(response);
  }
}
