import 'package:dio/dio.dart';

import '../../../../../features/transport/v2/transport_v2_models.dart';
import '../../../../errors/api_failure.dart';
import '../../../../errors/api_failure_mapper.dart';
import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import 'transport_v2_api_paths.dart';

/// Dio-backed data source for the Transport v2 API.
///
/// DELIBERATE DIFFERENCES FROM THE LEGACY DATA SOURCE
///
/// 1. NO mock write-fallback. The legacy path wrapped every write in
///    `withMockWriteFallback`, which on an unreachable API silently executed a
///    MOCK and returned success — the UI said "Stops updated" while nothing had
///    persisted. BUS-008 restricted that to debug builds; v2 does not have it at
///    all. A failed write fails.
/// 2. Domain errors are mapped to typed failures. The backend's error codes
///    (ROUTE_INCOMPLETE, CAPACITY_EXCEEDED, STOP_LOCATION_REQUIRED, …) carry
///    the operator's next action, so they must survive to the UI rather than
///    collapsing into "something went wrong".
/// 3. Every method returns a parsed domain model, never a loose Map.
class TransportV2DataSource {
  TransportV2DataSource(this._dio);

  final Dio _dio;

  // ─── Reads ─────────────────────────────────────────────────────────────────

  Future<List<TransportRouteV2>> fetchRoutes({
    required RepositoryQuery query,
    String? serviceDate,
  }) async {
    final data = await _get(
      TransportV2ApiPaths.routes,
      query: query,
      extra: {if (serviceDate != null) 'serviceDate': serviceDate},
    );
    final items = data['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map<String, dynamic>) TransportRouteV2.fromJson(item),
    ];
  }

  Future<TransportRouteV2> fetchRoute({
    required RepositoryQuery query,
    required String routeId,
    String? serviceDate,
  }) async {
    final data = await _get(
      TransportV2ApiPaths.route(routeId),
      query: query,
      extra: {if (serviceDate != null) 'serviceDate': serviceDate},
    );
    return TransportRouteV2.fromJson(data);
  }

  Future<List<TransportStopV2>> fetchStops({
    required RepositoryQuery query,
  }) async {
    final data = await _get(TransportV2ApiPaths.stops, query: query);
    final items = data['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map<String, dynamic>) TransportStopV2.fromJson(item),
    ];
  }

  /// BUS-043/054 — vehicles with compliance + commitment for the picker.
  Future<List<VehicleV2>> fetchVehicles({
    required RepositoryQuery query,
    String? serviceDate,
  }) async {
    final data = await _get(
      TransportV2ApiPaths.vehicles,
      query: query,
      extra: {if (serviceDate != null) 'serviceDate': serviceDate},
    );
    final items = data['items'];
    return [
      if (items is List)
        for (final i in items)
          if (i is Map<String, dynamic>) VehicleV2.fromJson(i),
    ];
  }

  /// BUS-048/050/054 — drivers with licence, leave and commitment state.
  Future<List<DriverV2>> fetchDrivers({
    required RepositoryQuery query,
    String? serviceDate,
  }) async {
    final data = await _get(
      TransportV2ApiPaths.drivers,
      query: query,
      extra: {if (serviceDate != null) 'serviceDate': serviceDate},
    );
    final items = data['items'];
    return [
      if (items is List)
        for (final i in items)
          if (i is Map<String, dynamic>) DriverV2.fromJson(i),
    ];
  }

  Future<RouteReadinessV2> fetchRouteReadiness({
    required RepositoryQuery query,
    required String routeId,
  }) async {
    // POST-shaped probe (the backend runs it through the write-context helper so
    // it shares the gate's exact logic — see BUS-042).
    final data = await _post(
      TransportV2ApiPaths.routeReadiness(routeId),
      query: query,
      body: const {},
    );
    return RouteReadinessV2.fromJson(data);
  }

  Future<RouteCapacityV2> fetchRouteCapacity({
    required RepositoryQuery query,
    required String routeId,
    int adding = 0,
    String? serviceDate,
  }) async {
    final data = await _post(
      TransportV2ApiPaths.routeCapacityCheck(routeId),
      query: query,
      body: {
        'adding': adding,
        if (serviceDate != null) 'serviceDate': serviceDate,
      },
    );
    return RouteCapacityV2.fromJson(data);
  }

  Future<List<UnstaffedRouteV2>> fetchUnstaffedRoutes({
    required RepositoryQuery query,
    String? serviceDate,
  }) async {
    final data = await _post(
      TransportV2ApiPaths.unstaffedRoutes,
      query: query,
      body: {if (serviceDate != null) 'serviceDate': serviceDate},
    );
    final rows = data['routes'];
    return [
      if (rows is List)
        for (final r in rows)
          if (r is Map<String, dynamic>) UnstaffedRouteV2.fromJson(r),
    ];
  }

  // ─── Route writes (BUS-033/034/035/042) ────────────────────────────────────

  Future<String> createRoute({
    required RepositoryQuery query,
    required String name,
    required RouteV2Shift shift,
    RouteV2Direction direction = RouteV2Direction.pickup,
    String code = '',
    StopTime? defaultDepartureTime,
    StopTime? defaultReturnTime,
    int? distanceM,
  }) async {
    final data = await _post(
      TransportV2ApiPaths.routes,
      query: query,
      body: {
        'name': name,
        'shift': shift.name,
        'direction': direction.name,
        if (code.isNotEmpty) 'code': code,
        if (defaultDepartureTime != null)
          'defaultDepartureTime': defaultDepartureTime.toWire(),
        if (defaultReturnTime != null)
          'defaultReturnTime': defaultReturnTime.toWire(),
        if (distanceM != null) 'distanceM': distanceM,
      },
    );
    return data['id'] as String? ?? '';
  }

  /// Partial update. Only non-null arguments are sent, so an untouched field is
  /// left alone server-side — BUS-007's lesson applied at the wire boundary.
  Future<void> updateRoute({
    required RepositoryQuery query,
    required String routeId,
    String? name,
    String? code,
    RouteV2Shift? shift,
    RouteV2Direction? direction,
    StopTime? defaultDepartureTime,
    StopTime? defaultReturnTime,
    int? distanceM,
  }) async {
    await _put(
      TransportV2ApiPaths.route(routeId),
      query: query,
      body: {
        if (name != null) 'name': name,
        if (code != null) 'code': code,
        if (shift != null) 'shift': shift.name,
        if (direction != null) 'direction': direction.name,
        if (defaultDepartureTime != null)
          'defaultDepartureTime': defaultDepartureTime.toWire(),
        if (defaultReturnTime != null)
          'defaultReturnTime': defaultReturnTime.toWire(),
        if (distanceM != null) 'distanceM': distanceM,
      },
    );
  }

  Future<void> activateRoute({
    required RepositoryQuery query,
    required String routeId,
  }) =>
      _post(TransportV2ApiPaths.activateRoute(routeId),
              query: query, body: const {})
          .then((_) {});

  Future<int> deactivateRoute({
    required RepositoryQuery query,
    required String routeId,
  }) async {
    final data = await _post(
      TransportV2ApiPaths.deactivateRoute(routeId),
      query: query,
      body: const {},
    );
    // How many children still reference the route — the admin needs this to
    // re-home them, so it is returned rather than swallowed.
    return (data['studentsStillAllocated'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteRoute({
    required RepositoryQuery query,
    required String routeId,
  }) =>
      _delete(TransportV2ApiPaths.route(routeId), query: query);

  // ─── Stop writes (BUS-036/037/038/039) ─────────────────────────────────────

  Future<String> createStop({
    required RepositoryQuery query,
    required String name,
    required GeoPoint location,
    int geofenceRadiusM = 100,
    String addressText = '',
    String landmark = '',
  }) async {
    final data = await _post(
      TransportV2ApiPaths.stops,
      query: query,
      body: {
        'name': name,
        // A validated GeoPoint cannot be (0,0), so the wire payload is
        // guaranteed to satisfy the backend's coordinate mandate.
        'latitude': location.latitude,
        'longitude': location.longitude,
        'geofenceRadiusM': geofenceRadiusM,
        if (addressText.isNotEmpty) 'addressText': addressText,
        if (landmark.isNotEmpty) 'landmark': landmark,
      },
    );
    return data['id'] as String? ?? '';
  }

  Future<void> updateStop({
    required RepositoryQuery query,
    required String stopId,
    String? name,
    GeoPoint? location,
    int? geofenceRadiusM,
    String? addressText,
    String? landmark,
  }) async {
    await _put(
      TransportV2ApiPaths.stop(stopId),
      query: query,
      body: {
        if (name != null) 'name': name,
        if (location != null) 'latitude': location.latitude,
        if (location != null) 'longitude': location.longitude,
        if (geofenceRadiusM != null) 'geofenceRadiusM': geofenceRadiusM,
        if (addressText != null) 'addressText': addressText,
        if (landmark != null) 'landmark': landmark,
      },
    );
  }

  Future<void> deleteStop({
    required RepositoryQuery query,
    required String stopId,
  }) =>
      _delete(TransportV2ApiPaths.stop(stopId), query: query);

  Future<void> attachStop({
    required RepositoryQuery query,
    required String routeId,
    required String stopId,
    StopTime? pickupTime,
    StopTime? dropTime,
    int dwellSeconds = 60,
  }) async {
    await _post(
      TransportV2ApiPaths.routeStops(routeId),
      query: query,
      body: {
        'stopId': stopId,
        if (pickupTime != null) 'pickupTime': pickupTime.toWire(),
        if (dropTime != null) 'dropTime': dropTime.toWire(),
        'dwellSeconds': dwellSeconds,
      },
    );
  }

  /// Times are only sent when explicitly supplied — an omitted time is NOT
  /// cleared. This is the wire-level guard against BUS-007's erasure defect.
  Future<void> updateRouteStop({
    required RepositoryQuery query,
    required String routeId,
    required String stopId,
    StopTime? pickupTime,
    StopTime? dropTime,
    int? dwellSeconds,
  }) async {
    await _put(
      TransportV2ApiPaths.routeStop(routeId, stopId),
      query: query,
      body: {
        if (pickupTime != null) 'pickupTime': pickupTime.toWire(),
        if (dropTime != null) 'dropTime': dropTime.toWire(),
        if (dwellSeconds != null) 'dwellSeconds': dwellSeconds,
      },
    );
  }

  Future<void> detachStop({
    required RepositoryQuery query,
    required String routeId,
    required String stopId,
  }) =>
      _delete(TransportV2ApiPaths.routeStop(routeId, stopId), query: query);

  Future<void> reorderStops({
    required RepositoryQuery query,
    required String routeId,
    required List<String> stopOrder,
  }) async {
    await _post(
      TransportV2ApiPaths.routeStopsReorder(routeId),
      query: query,
      body: {'stopOrder': stopOrder},
    );
  }

  // ─── Assignment writes (BUS-043/046/048/051/054) ───────────────────────────

  Future<RouteAssignmentV2> setAssignment({
    required RepositoryQuery query,
    required String routeId,
    String? vehicleId,
    String? driverId,
    String? attendantId,
    String? effectiveFrom,
    String reason = '',
    bool allowNonCompliant = false,
  }) async {
    final data = await _put(
      TransportV2ApiPaths.routeAssignment(routeId),
      query: query,
      body: {
        if (vehicleId != null) 'vehicleId': vehicleId,
        if (driverId != null) 'driverId': driverId,
        if (attendantId != null) 'attendantId': attendantId,
        if (effectiveFrom != null) 'effectiveFrom': effectiveFrom,
        if (reason.isNotEmpty) 'reason': reason,
        // Never defaulted true: an out-of-compliance assignment must be a
        // deliberate, separately-audited act (BUS-054).
        if (allowNonCompliant) 'allowNonCompliant': true,
      },
    );
    return RouteAssignmentV2.fromJson(data);
  }

  /// BUS-051 — substitute for a bounded range. `tripsRebound` matters: if trip
  /// generation already ran, those trips are re-pointed, otherwise the
  /// substitute would log in and see nothing.
  Future<({RouteAssignmentV2 assignment, int tripsRebound})> substituteAssignment({
    required RepositoryQuery query,
    required String routeId,
    required String reason,
    String? vehicleId,
    String? driverId,
    String? attendantId,
    String? effectiveFrom,
    String? effectiveTo,
    bool allowNonCompliant = false,
  }) async {
    final data = await _post(
      TransportV2ApiPaths.routeSubstitute(routeId),
      query: query,
      body: {
        'reason': reason,
        if (vehicleId != null) 'vehicleId': vehicleId,
        if (driverId != null) 'driverId': driverId,
        if (attendantId != null) 'attendantId': attendantId,
        if (effectiveFrom != null) 'effectiveFrom': effectiveFrom,
        if (effectiveTo != null) 'effectiveTo': effectiveTo,
        if (allowNonCompliant) 'allowNonCompliant': true,
      },
    );
    return (
      assignment: RouteAssignmentV2.fromJson(data),
      tripsRebound: (data['tripsRebound'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> cancelSubstitute({
    required RepositoryQuery query,
    required String assignmentId,
  }) async {
    final data = await _deleteReturning(
      TransportV2ApiPaths.assignment(assignmentId),
      query: query,
    );
    return (data['tripsRebound'] as num?)?.toInt() ?? 0;
  }

  Future<List<UnstaffedRouteV2>> setDriverAvailability({
    required RepositoryQuery query,
    required String driverId,
    required String fromDate,
    required String toDate,
    String kind = 'leave',
    String reason = '',
  }) async {
    final data = await _post(
      TransportV2ApiPaths.driverAvailability(driverId),
      query: query,
      body: {
        'fromDate': fromDate,
        'toDate': toDate,
        'kind': kind,
        if (reason.isNotEmpty) 'reason': reason,
      },
    );
    // Which routes this leave leaves uncovered — surfaced so the admin can
    // arrange a substitute now rather than at 7 a.m. (BUS-050).
    final rows = data['routesNeedingSubstitute'];
    return [
      if (rows is List)
        for (final r in rows)
          if (r is Map<String, dynamic>) UnstaffedRouteV2.fromJson(r),
    ];
  }

  Future<void> deleteVehicle({
    required RepositoryQuery query,
    required String vehicleId,
  }) =>
      _delete(TransportV2ApiPaths.vehicle(vehicleId), query: query);

  Future<void> deleteDriver({
    required RepositoryQuery query,
    required String driverId,
  }) =>
      _delete(TransportV2ApiPaths.driver(driverId), query: query);

  // ─── Transport ────────────────────────────────────────────────────────────

  Map<String, dynamic> _params(RepositoryQuery query, [Map<String, dynamic>? extra]) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
      ...?extra,
    };
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    required RepositoryQuery query,
    Map<String, dynamic>? extra,
  }) async {
    return _guard(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: _params(query, extra),
      );
      return _data(res);
    });
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    return _guard(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        path,
        queryParameters: _params(query),
        data: body,
      );
      return _data(res);
    });
  }

  Future<Map<String, dynamic>> _put(
    String path, {
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    return _guard(() async {
      final res = await _dio.put<Map<String, dynamic>>(
        path,
        queryParameters: _params(query),
        data: body,
      );
      return _data(res);
    });
  }

  Future<void> _delete(String path, {required RepositoryQuery query}) async {
    await _deleteReturning(path, query: query);
  }

  Future<Map<String, dynamic>> _deleteReturning(
    String path, {
    required RepositoryQuery query,
  }) async {
    return _guard(() async {
      final res = await _dio.delete<Map<String, dynamic>>(
        path,
        queryParameters: _params(query),
      );
      return _data(res);
    });
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> res) =>
      ApiEnvelopeDto.fromJson(res.data ?? const {}).requireData();

  /// Maps transport errors to typed failures, PRESERVING the backend error code.
  ///
  /// The codes are the operator's instructions — ROUTE_INCOMPLETE lists what is
  /// missing, STOP_HAS_ALLOCATIONS says who to move first, COMPLIANCE_BLOCKED
  /// names the expired document. Collapsing them into a generic message would
  /// throw away the only actionable content in the response.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      final body = error.response?.data;
      String? code;
      String? message;
      if (body is Map<String, dynamic>) {
        final err = body['error'];
        if (err is Map<String, dynamic>) {
          code = err['code'] as String?;
          message = err['message'] as String?;
        }
      }
      if (code != null) {
        throw ApiFailureException(
          ApiFailure(
            type: _typeForStatus(error.response?.statusCode),
            message: message ?? 'Transport request failed',
            code: code,
            statusCode: error.response?.statusCode,
            cause: error,
          ),
        );
      }
      throw ApiFailureException(apiFailureMapper.fromException(error));
    }
  }

  ApiFailureType _typeForStatus(int? status) {
    if (status == null) return ApiFailureType.unknown;
    if (status == 401) return ApiFailureType.unauthorized;
    if (status == 403) return ApiFailureType.forbidden;
    // 409/422 are DOMAIN outcomes, not server faults: the request was understood
    // and deliberately refused. Typing them as `server` would make the UI offer
    // a pointless "retry" for something retrying cannot fix.
    if (status == 409 || status == 422) return ApiFailureType.unknown;
    if (status >= 500) return ApiFailureType.server;
    return ApiFailureType.unknown;
  }
}

/// Domain error codes the v2 API returns. Kept as constants so screens branch on
/// a symbol rather than a string literal.
abstract final class TransportV2ErrorCodes {
  static const routeIncomplete = 'ROUTE_INCOMPLETE';
  static const routeInUse = 'ROUTE_IN_USE';
  static const stopInUse = 'STOP_IN_USE';
  static const stopHasAllocations = 'STOP_HAS_ALLOCATIONS';
  static const stopLocationRequired = 'STOP_LOCATION_REQUIRED';
  static const stopLocationInvalid = 'STOP_LOCATION_INVALID';
  static const capacityExceeded = 'CAPACITY_EXCEEDED';
  static const complianceBlocked = 'COMPLIANCE_BLOCKED';
  static const driverUnavailable = 'DRIVER_UNAVAILABLE';
  static const driverDoubleBooked = 'DRIVER_DOUBLE_BOOKED';
  static const vehicleDoubleBooked = 'VEHICLE_DOUBLE_BOOKED';
  static const vehicleInUse = 'VEHICLE_IN_USE';
  static const driverInUse = 'DRIVER_IN_USE';
  static const notASubstitute = 'NOT_A_SUBSTITUTE';
  static const invalidTime = 'INVALID_TIME';
  static const nothingToAssign = 'NOTHING_TO_ASSIGN';

  /// True when the failure is a deliberate domain refusal the user can act on,
  /// rather than a transport fault worth retrying.
  static bool isActionable(String? code) =>
      code != null && code.isNotEmpty && code != 'INTERNAL_ERROR';
}
