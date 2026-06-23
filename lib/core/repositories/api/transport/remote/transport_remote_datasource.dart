import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../../../../features/transport/transport_requests.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../dto/transport_enum_codec.dart';
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

  Future<TransportRouteDto> createRoute({
    required RepositoryQuery query,
    required CreateTransportRouteRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.routes,
      queryParameters: _queryParams(query),
      data: {
        'name': request.name,
        'distanceKm': request.distanceKm,
        'amDeparture': request.amDeparture,
        'pmDeparture': request.pmDeparture,
        'shift': TransportEnumCodec.shiftToApi(request.shift),
      },
    );
    return TransportRouteDto.fromJson(_writeData(response));
  }

  Future<TransportRouteDto> activateRoute({
    required RepositoryQuery query,
    required ActivateTransportRouteRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.activateRoute(request.routeId),
      queryParameters: _queryParams(query),
      data: const <String, dynamic>{},
    );
    return TransportRouteDto.fromJson(_writeData(response));
  }

  Future<TransportAllocationDto> assignStudentTransport({
    required RepositoryQuery query,
    required AssignStudentTransportRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.allocations,
      queryParameters: _queryParams(query),
      data: {
        'allocationId': request.allocationId,
        'routeId': request.routeId,
        'pickupStop': request.pickupStop,
        'dropStop': request.dropStop,
      },
    );
    return TransportAllocationDto.fromJson(_writeData(response));
  }

  Future<TransportAllocationDto> transferStudentTransport({
    required RepositoryQuery query,
    required TransferStudentTransportRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.transferAllocation(request.allocationId),
      queryParameters: _queryParams(query),
      data: {
        'targetRouteId': request.targetRouteId,
        'pickupStop': request.pickupStop,
        'dropStop': request.dropStop,
      },
    );
    return TransportAllocationDto.fromJson(_writeData(response));
  }

  Future<TransportAllocationDto> removeStudentTransport({
    required RepositoryQuery query,
    required RemoveStudentTransportRequest request,
  }) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      TransportApiPaths.allocation(request.allocationId),
      queryParameters: _queryParams(query),
    );
    return TransportAllocationDto.fromJson(_writeData(response));
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
      ...query.paginationQueryParams(),
    };
  }

  /// Unwraps the `{data, error}` envelope returned by write endpoints.
  Map<String, dynamic> _writeData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(_responseMap(response)).requireData();
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }
}
