import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import 'restaurant_api_paths.dart';

class RestaurantRemoteDataSource {
  RestaurantRemoteDataSource(this._dio);

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
      RestaurantApiPaths.dashboard,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchIntelligence({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      RestaurantApiPaths.intelligence,
      queryParameters: _params(query),
    );
    return _data(response);
  }
}
