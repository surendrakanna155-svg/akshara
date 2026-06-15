import 'package:dio/dio.dart';

import '../../admissions/dto/api_envelope_dto.dart';
import '../../../repository_query.dart';
import 'white_label_api_paths.dart';

class WhiteLabelRemoteDataSource {
  WhiteLabelRemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) =>
      ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();

  Map<String, dynamic> _params(RepositoryQuery query) => {
        'tenantId': query.tenantId,
        if (query.schoolId != null) 'schoolId': query.schoolId,
        if (query.organizationId != null)
          'organizationId': query.organizationId,
      };

  Future<Map<String, dynamic>> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      WhiteLabelApiPaths.dashboard,
      queryParameters: _params(query),
    );
    return _data(response);
  }
}
