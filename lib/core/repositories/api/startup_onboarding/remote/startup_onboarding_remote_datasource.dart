import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import 'startup_onboarding_api_paths.dart';

class StartupOnboardingRemoteDataSource {
  StartupOnboardingRemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _unwrap(Response<Map<String, dynamic>> response) {
    final envelope = response.data ?? const <String, dynamic>{};
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

  Map<String, String> _queryParams(RepositoryQuery query) {
    final params = <String, String>{};
    final orgId = query.organizationId;
    final schoolId = query.schoolId;
    if (orgId != null && orgId.isNotEmpty) params['organizationId'] = orgId;
    if (schoolId != null && schoolId.isNotEmpty) params['schoolId'] = schoolId;
    return params;
  }

  Future<Map<String, dynamic>> fetchStartupOnboarding({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      StartupOnboardingApiPaths.startup,
      queryParameters: _queryParams(query),
    );
    return _unwrap(response);
  }

  Future<Map<String, dynamic>> saveStartupOnboarding({
    required RepositoryQuery query,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      StartupOnboardingApiPaths.startup,
      data: payload,
      queryParameters: _queryParams(query),
    );
    return _unwrap(response);
  }

  Future<Map<String, dynamic>> goLiveStartupOnboarding({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      StartupOnboardingApiPaths.goLive,
      queryParameters: _queryParams(query),
    );
    return _unwrap(response);
  }

  Future<Map<String, dynamic>> aiPrefillStartupOnboarding({
    required RepositoryQuery query,
    required Map<String, dynamic> brief,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      StartupOnboardingApiPaths.aiPrefill,
      data: brief,
      queryParameters: _queryParams(query),
    );
    return _unwrap(response);
  }
}
