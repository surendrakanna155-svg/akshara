import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';

class MultiSchoolOperationsRemoteDataSource {
  MultiSchoolOperationsRemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) =>
      ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();

  Map<String, dynamic> _params(RepositoryQuery query) => {
        'tenantId': query.tenantId,
        if (query.schoolId != null) 'schoolId': query.schoolId,
        if (query.organizationId != null)
          'organizationId': query.organizationId,
      };

  Future<Map<String, dynamic>> fetchPortfolioDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/multi-school/portfolio/dashboard',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchSchools({
    required RepositoryQuery query,
    String? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/multi-school/schools',
      queryParameters: {
        ..._params(query),
        if (status != null) 'status': status,
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchSchoolHealth({
    required RepositoryQuery query,
    required String schoolId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/multi-school/schools/$schoolId/health',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> createOnboardingDraft({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/multi-school/onboarding/drafts',
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> submitOnboarding({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/multi-school/onboarding/drafts/$draftId/submit',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> activateSchool({
    required RepositoryQuery query,
    required String schoolId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/multi-school/schools/$schoolId/activate',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> deactivateSchool({
    required RepositoryQuery query,
    required String schoolId,
    String? reason,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/multi-school/schools/$schoolId/deactivate',
      queryParameters: _params(query),
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchAlerts({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/multi-school/alerts',
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> dismissAlert({
    required RepositoryQuery query,
    required String alertId,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/multi-school/alerts/$alertId/dismiss',
      queryParameters: _params(query),
    );
  }

  Future<List<Map<String, dynamic>>> fetchPendingActions({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/multi-school/actions',
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> completeAction({
    required RepositoryQuery query,
    required String actionId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/multi-school/actions/$actionId/complete',
      queryParameters: _params(query),
    );
    return _data(response);
  }
}
