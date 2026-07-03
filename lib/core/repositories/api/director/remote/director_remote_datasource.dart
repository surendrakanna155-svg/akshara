import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';

/// Thin HTTP client for the Director portal endpoints. All reads are org-scoped
/// aggregates ("Aggregated data only · No student PII"); the two writes
/// (acknowledge compliance, export report) require `manageDirectorPortal`.
class DirectorRemoteDataSource {
  DirectorRemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) =>
      ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();

  Map<String, dynamic> _params(RepositoryQuery query) => {
        'tenantId': query.tenantId,
        if (query.schoolId != null) 'schoolId': query.schoolId,
        if (query.organizationId != null)
          'organizationId': query.organizationId,
      };

  Future<Map<String, dynamic>> _get(
    String path,
    RepositoryQuery query,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchDashboard({required RepositoryQuery query}) =>
      _get('/director/dashboard', query);

  Future<List<Map<String, dynamic>>> fetchSchools({
    required RepositoryQuery query,
  }) async {
    final data = await _get('/director/schools', query);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  // DIR-2 — consolidated collection report: { schools: [...], totals: {...} }.
  Future<Map<String, dynamic>> fetchCollections({
    required RepositoryQuery query,
  }) =>
      _get('/director/collections', query);

  // DIR-D1 — audited, read-only per-school snapshot. The backend audits this
  // read; a foreign school → 404 (surfaces as an ApiFailure to the caller).
  Future<Map<String, dynamic>> fetchSchoolSnapshot({
    required RepositoryQuery query,
    required String schoolId,
  }) =>
      _get('/director/schools/$schoolId/snapshot', query);

  Future<Map<String, dynamic>> fetchPortfolio({required RepositoryQuery query}) =>
      _get('/director/portfolio', query);

  Future<Map<String, dynamic>> fetchRevenue({required RepositoryQuery query}) =>
      _get('/director/revenue', query);

  Future<Map<String, dynamic>> fetchGrowth({required RepositoryQuery query}) =>
      _get('/director/growth', query);

  Future<Map<String, dynamic>> fetchMarketing({required RepositoryQuery query}) =>
      _get('/director/marketing', query);

  Future<Map<String, dynamic>> fetchAdmissions({required RepositoryQuery query}) =>
      _get('/director/admissions', query);

  Future<List<Map<String, dynamic>>> fetchCompliance({
    required RepositoryQuery query,
  }) async {
    final data = await _get('/director/compliance', query);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchReports({
    required RepositoryQuery query,
  }) async {
    final data = await _get('/director/reports', query);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<String> generateSummary({
    required RepositoryQuery query,
    required String focusArea,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/director/summary',
      queryParameters: _params(query),
      data: {'focusArea': focusArea},
    );
    return _data(response)['summary'] as String? ?? '';
  }

  Future<Map<String, dynamic>> acknowledgeCompliance({
    required RepositoryQuery query,
    required String complianceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/director/compliance/$complianceId/acknowledge',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchMetricInputs({
    required RepositoryQuery query,
  }) async {
    final data = await _get('/director/metric-inputs', query);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> saveMetricInput({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/director/metric-inputs',
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> exportReport({
    required RepositoryQuery query,
    required String reportId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/director/reports/$reportId/export',
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['document'] as Map<String, dynamic>?) ?? data;
  }
}
