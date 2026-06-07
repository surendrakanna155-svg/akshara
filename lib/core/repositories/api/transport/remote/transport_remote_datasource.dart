import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../dto/transport_responses_dto.dart';
import 'transport_api_paths.dart';

/// Dio-backed remote data source for Transport.
class TransportRemoteDataSource {
  TransportRemoteDataSource(this._dio);

  final Dio _dio;

  Future<TransportDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TransportApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return TransportDashboardDto.fromJson(_responseMap(response));
  }

  Future<TransportRoutesResponseDto> fetchRoutes({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TransportApiPaths.routes,
      queryParameters: _queryParams(query),
    );
    return TransportRoutesResponseDto.fromJson(_responseMap(response));
  }

  Future<TransportVehiclesResponseDto> fetchVehicles({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TransportApiPaths.vehicles,
      queryParameters: _queryParams(query),
    );
    return TransportVehiclesResponseDto.fromJson(_responseMap(response));
  }

  Future<TransportDriversResponseDto> fetchDrivers({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TransportApiPaths.drivers,
      queryParameters: _queryParams(query),
    );
    return TransportDriversResponseDto.fromJson(_responseMap(response));
  }

  Future<TransportAllocationsResponseDto> fetchAllocations({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TransportApiPaths.allocations,
      queryParameters: _queryParams(query),
    );
    return TransportAllocationsResponseDto.fromJson(_responseMap(response));
  }

  Future<TransportAttendanceResponseDto> fetchAttendanceRecords({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TransportApiPaths.attendance,
      queryParameters: _queryParams(query),
    );
    return TransportAttendanceResponseDto.fromJson(_responseMap(response));
  }

  Future<TransportTrackingDto> fetchTrackingPlaceholder({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TransportApiPaths.tracking,
      queryParameters: _queryParams(query),
    );
    return TransportTrackingDto.fromJson(_responseMap(response));
  }

  Future<TransportReportsDto> fetchReports({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TransportApiPaths.reports,
      queryParameters: _queryParams(query),
    );
    return TransportReportsDto.fromJson(_responseMap(response));
  }

  Future<TransportSettingsDto> fetchSettings({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TransportApiPaths.settings,
      queryParameters: _queryParams(query),
    );
    return TransportSettingsDto.fromJson(_responseMap(response));
  }

  Future<OccupancyMetricsDto> fetchOccupancyMetrics({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TransportApiPaths.occupancyMetrics,
      queryParameters: _queryParams(query),
    );
    return OccupancyMetricsDto.fromJson(_responseMap(response));
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
