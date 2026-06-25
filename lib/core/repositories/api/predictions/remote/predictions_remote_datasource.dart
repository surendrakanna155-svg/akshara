import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';

/// Thin HTTP client for the Advanced AI Predictions endpoints. All reads are
/// school-scoped and gated behind the `feature.ai_predictions` entitlement.
class PredictionsRemoteDataSource {
  PredictionsRemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) =>
      ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();

  Map<String, dynamic> _params(RepositoryQuery query) => {
        'tenantId': query.tenantId,
        if (query.schoolId != null) 'schoolId': query.schoolId,
        if (query.organizationId != null)
          'organizationId': query.organizationId,
      };

  Future<Map<String, dynamic>> _get(String path, RepositoryQuery query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchFeeDefault({required RepositoryQuery query}) =>
      _get('/predictions/fee-default', query);

  Future<Map<String, dynamic>> fetchAdmissionConversion({
    required RepositoryQuery query,
  }) =>
      _get('/predictions/admission-conversion', query);

  Future<Map<String, dynamic>> fetchStudentRisk({required RepositoryQuery query}) =>
      _get('/predictions/student-risk', query);
}
