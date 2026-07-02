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

  Future<TransportAttendanceRecordDto> recordAttendance({
    required RepositoryQuery query,
    required RecordTransportAttendanceRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.attendance,
      queryParameters: _queryParams(query),
      data: {
        if (request.id != null) 'id': request.id,
        'studentName': request.studentName,
        'stopName': request.stopName,
        'routeName': request.routeName,
        'scheduledTime': request.scheduledTime,
        'actualTime': request.actualTime,
        'status': TransportEnumCodec.attendanceStatusToApi(request.status),
        'parentNotified': request.parentNotified,
        'shift': TransportEnumCodec.shiftToApi(request.shift),
      },
    );
    return TransportAttendanceRecordDto.fromJson(_writeData(response));
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
        'studentName': request.studentName,
        'admissionNumber': request.admissionNumber,
        'sisStudentId': request.sisStudentId,
        'classLabel': request.classLabel,
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

  Future<TransportDelayNotificationDto> notifyRouteDelay({
    required RepositoryQuery query,
    required NotifyRouteDelayRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.notifyDelay,
      queryParameters: _queryParams(query),
      data: {
        'routeId': request.routeId,
        'message': request.message,
      },
    );
    return TransportDelayNotificationDto.fromJson(_writeData(response));
  }

  // ─── TRN-1/TRN-2: vehicle CRUD ──────────────────────────────────────────────

  Future<TransportVehicleDto> createVehicle({
    required RepositoryQuery query,
    required CreateTransportVehicleRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.vehicles,
      queryParameters: _queryParams(query),
      data: {
        'registration': request.registration,
        'model': request.model,
        'capacity': request.capacity,
        'status': TransportEnumCodec.vehicleStatusToApi(request.status),
        if (request.insuranceExpiry.isNotEmpty)
          'insuranceExpiry': request.insuranceExpiry,
        if (request.fitnessExpiry.isNotEmpty)
          'fitnessExpiry': request.fitnessExpiry,
        if (request.pucExpiry.isNotEmpty) 'pucExpiry': request.pucExpiry,
        if (request.permitExpiry.isNotEmpty)
          'permitExpiry': request.permitExpiry,
        if (request.roadTaxExpiry.isNotEmpty)
          'roadTaxExpiry': request.roadTaxExpiry,
      },
    );
    return TransportVehicleDto.fromJson(_writeData(response));
  }

  Future<TransportVehicleDto> updateVehicle({
    required RepositoryQuery query,
    required UpdateTransportVehicleRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      TransportApiPaths.vehicle(request.id),
      queryParameters: _queryParams(query),
      data: {
        if (request.registration != null) 'registration': request.registration,
        if (request.model != null) 'model': request.model,
        if (request.capacity != null) 'capacity': request.capacity,
        if (request.status != null)
          'status': TransportEnumCodec.vehicleStatusToApi(request.status!),
        if (request.insuranceExpiry != null)
          'insuranceExpiry': request.insuranceExpiry,
        if (request.fitnessExpiry != null)
          'fitnessExpiry': request.fitnessExpiry,
        if (request.pucExpiry != null) 'pucExpiry': request.pucExpiry,
        if (request.permitExpiry != null) 'permitExpiry': request.permitExpiry,
        if (request.roadTaxExpiry != null)
          'roadTaxExpiry': request.roadTaxExpiry,
      },
    );
    return TransportVehicleDto.fromJson(_writeData(response));
  }

  Future<TransportVehicleDto> deleteVehicle({
    required RepositoryQuery query,
    required DeleteTransportVehicleRequest request,
  }) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      TransportApiPaths.vehicle(request.id),
      queryParameters: _queryParams(query),
    );
    return TransportVehicleDto.fromJson(_writeData(response));
  }

  // ─── TRN-1/TRN-2: driver CRUD ───────────────────────────────────────────────

  Future<TransportDriverDto> createDriver({
    required RepositoryQuery query,
    required CreateTransportDriverRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.drivers,
      queryParameters: _queryParams(query),
      data: {
        'name': request.name,
        'licenseNumber': request.licenseNumber,
        'phone': request.phone,
        'status': TransportEnumCodec.driverStatusToApi(request.status),
        if (request.licenseExpiry.isNotEmpty)
          'licenseExpiry': request.licenseExpiry,
      },
    );
    return TransportDriverDto.fromJson(_writeData(response));
  }

  Future<TransportDriverDto> updateDriver({
    required RepositoryQuery query,
    required UpdateTransportDriverRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      TransportApiPaths.driver(request.id),
      queryParameters: _queryParams(query),
      data: {
        if (request.name != null) 'name': request.name,
        if (request.licenseNumber != null)
          'licenseNumber': request.licenseNumber,
        if (request.phone != null) 'phone': request.phone,
        if (request.status != null)
          'status': TransportEnumCodec.driverStatusToApi(request.status!),
        if (request.licenseExpiry != null)
          'licenseExpiry': request.licenseExpiry,
      },
    );
    return TransportDriverDto.fromJson(_writeData(response));
  }

  Future<TransportDriverDto> deleteDriver({
    required RepositoryQuery query,
    required DeleteTransportDriverRequest request,
  }) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      TransportApiPaths.driver(request.id),
      queryParameters: _queryParams(query),
    );
    return TransportDriverDto.fromJson(_writeData(response));
  }

  // ─── TRN-3: stop-wise roster (read) ─────────────────────────────────────────

  Future<TransportRosterDto> fetchRouteRoster({
    required RepositoryQuery query,
    required String routeId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TransportApiPaths.routeRoster(routeId),
      queryParameters: _queryParams(query),
    );
    return TransportRosterDto.fromJson(_responseMap(response));
  }

  // ─── TRN-4: stop editor ─────────────────────────────────────────────────────

  Future<TransportRouteDto> addStop({
    required RepositoryQuery query,
    required AddTransportStopRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.routeStops(request.routeId),
      queryParameters: _queryParams(query),
      data: {
        'name': request.name,
        'pickupTime': request.pickupTime,
        'dropTime': request.dropTime,
      },
    );
    return TransportRouteDto.fromJson(_writeData(response));
  }

  Future<TransportRouteDto> updateStop({
    required RepositoryQuery query,
    required UpdateTransportStopRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      TransportApiPaths.routeStop(request.routeId, request.stopId),
      queryParameters: _queryParams(query),
      data: {
        if (request.name != null) 'name': request.name,
        if (request.pickupTime != null) 'pickupTime': request.pickupTime,
        if (request.dropTime != null) 'dropTime': request.dropTime,
      },
    );
    return TransportRouteDto.fromJson(_writeData(response));
  }

  Future<TransportRouteDto> removeStop({
    required RepositoryQuery query,
    required RemoveTransportStopRequest request,
  }) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      TransportApiPaths.routeStop(request.routeId, request.stopId),
      queryParameters: _queryParams(query),
    );
    return TransportRouteDto.fromJson(_writeData(response));
  }

  Future<TransportRouteDto> reorderStops({
    required RepositoryQuery query,
    required ReorderTransportStopsRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.routeStopsReorder(request.routeId),
      queryParameters: _queryParams(query),
      data: {'stopOrder': request.stopOrder},
    );
    return TransportRouteDto.fromJson(_writeData(response));
  }

  // ─── TRN-5: bulk allocation ─────────────────────────────────────────────────

  Future<BulkAllocationResultDto> bulkAllocateTransport({
    required RepositoryQuery query,
    required BulkAllocateTransportRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.allocationsBulk,
      queryParameters: _queryParams(query),
      data: {
        'routeId': request.routeId,
        'pickupStop': request.pickupStop,
        'dropStop': request.dropStop,
        if (request.sisStudentIds.isNotEmpty)
          'sisStudentIds': request.sisStudentIds,
        if (request.className != null) 'className': request.className,
        if (request.sectionName != null) 'sectionName': request.sectionName,
        'shift': TransportEnumCodec.shiftToApi(request.shift),
        'allowOverCapacity': request.allowOverCapacity,
      },
    );
    return BulkAllocationResultDto.fromJson(_writeData(response));
  }

  // ─── TRN-8: document-expiry reminder ────────────────────────────────────────

  Future<TransportDocumentExpiryReminderDto> sendDocumentExpiryReminder({
    required RepositoryQuery query,
    required SendTransportDocumentExpiryReminderRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.documentExpiryReminder,
      queryParameters: _queryParams(query),
      data: {'withinDays': request.withinDays},
    );
    return TransportDocumentExpiryReminderDto.fromJson(_writeData(response));
  }

  // ─── TRN-9: raise a Finance transport-fee demand ────────────────────────────

  Future<TransportDemandResultDto> raiseTransportDemand({
    required RepositoryQuery query,
    required RaiseTransportDemandRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TransportApiPaths.demands,
      queryParameters: _queryParams(query),
      data: {
        'sisStudentId': request.sisStudentId,
        'routeId': request.routeId,
        'feeStructureId': request.feeStructureId,
        'academicYear': request.academicYear,
        'term': request.term,
        if (request.allocationId.isNotEmpty)
          'allocationId': request.allocationId,
      },
    );
    return TransportDemandResultDto.fromJson(_writeData(response));
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
