import '../../../../../features/transport/v2/transport_v2_models.dart';
import '../../../repository_query.dart';
import 'transport_v2_datasource.dart';

/// Transport v2 repository.
///
/// OFFLINE STRATEGY — deliberately narrow.
///
/// Reads are cached in memory per (tenant, school) so a transient network blip
/// does not blank a screen the admin is mid-way through configuring. The cache
/// is served ONLY when a read fails, never in preference to a live read, and it
/// is always stamped so the UI can say how old it is.
///
/// Writes are NEVER queued or optimistically applied. That is the single most
/// important decision in this file, and it is the opposite of what the legacy
/// layer did: `withMockWriteFallback` silently ran a MOCK on an unreachable API
/// and returned success, so the UI reported "Stops updated" while nothing had
/// persisted (BUS-008).
///
/// A queued transport write would be worse than a failed one. Assignment,
/// substitution, capacity and publication are decisions with real-world
/// consequences — a substitute driver "queued" offline and never delivered means
/// a bus with no driver and an admin who believes it is covered. So a write that
/// cannot reach the backend fails loudly and the operator retries.
///
/// The DRIVER app is the one place a write queue IS correct (BUS-080
/// store-and-forward for position fixes and boarding marks), because those are
/// observations of something that already happened rather than instructions
/// about the future. That queue belongs to the driver lane, not here.
class TransportV2Repository {
  TransportV2Repository(this._remote);

  final TransportV2DataSource _remote;

  final Map<String, _CachedRoutes> _routeCache = {};
  final Map<String, _CachedStops> _stopCache = {};

  String _key(RepositoryQuery q) => '${q.tenantId}:${q.schoolId ?? '-'}';

  // ─── Reads (cache-on-failure) ──────────────────────────────────────────────

  /// Routes for the school. On failure returns the last good list marked stale,
  /// so a half-finished configuration screen is not wiped by a dropped request.
  Future<RoutesResult> getRoutes({
    required RepositoryQuery query,
    String? serviceDate,
  }) async {
    try {
      final routes = await _remote.fetchRoutes(
        query: query,
        serviceDate: serviceDate,
      );
      _routeCache[_key(query)] = _CachedRoutes(routes, DateTime.now());
      return RoutesResult(routes: routes, isStale: false, cachedAt: null);
    } catch (error) {
      final cached = _routeCache[_key(query)];
      if (cached == null) rethrow;
      return RoutesResult(
        routes: cached.routes,
        isStale: true,
        cachedAt: cached.at,
      );
    }
  }

  Future<TransportRouteV2> getRoute({
    required RepositoryQuery query,
    required String routeId,
    String? serviceDate,
  }) =>
      _remote.fetchRoute(
        query: query,
        routeId: routeId,
        serviceDate: serviceDate,
      );

  Future<StopsResult> getStops({required RepositoryQuery query}) async {
    try {
      final stops = await _remote.fetchStops(query: query);
      _stopCache[_key(query)] = _CachedStops(stops, DateTime.now());
      return StopsResult(stops: stops, isStale: false, cachedAt: null);
    } catch (error) {
      final cached = _stopCache[_key(query)];
      if (cached == null) rethrow;
      return StopsResult(
        stops: cached.stops,
        isStale: true,
        cachedAt: cached.at,
      );
    }
  }

  /// Fleet and crew are NEVER cached: their compliance and availability state
  /// gates an assignment decision, and a stale answer could let an admin put an
  /// uninsured bus or an on-leave driver on a route.
  Future<List<VehicleV2>> getVehicles({
    required RepositoryQuery query,
    String? serviceDate,
  }) =>
      _remote.fetchVehicles(query: query, serviceDate: serviceDate);

  Future<List<DriverV2>> getDrivers({
    required RepositoryQuery query,
    String? serviceDate,
  }) =>
      _remote.fetchDrivers(query: query, serviceDate: serviceDate);

  /// Readiness and capacity are NEVER served from cache. Both gate a decision
  /// (publish a route / add a child to a bus) and a stale answer could authorise
  /// something the live state forbids.
  Future<RouteReadinessV2> getRouteReadiness({
    required RepositoryQuery query,
    required String routeId,
  }) =>
      _remote.fetchRouteReadiness(query: query, routeId: routeId);

  Future<RouteCapacityV2> getRouteCapacity({
    required RepositoryQuery query,
    required String routeId,
    int adding = 0,
    String? serviceDate,
  }) =>
      _remote.fetchRouteCapacity(
        query: query,
        routeId: routeId,
        adding: adding,
        serviceDate: serviceDate,
      );

  Future<List<UnstaffedRouteV2>> getUnstaffedRoutes({
    required RepositoryQuery query,
    String? serviceDate,
  }) =>
      _remote.fetchUnstaffedRoutes(query: query, serviceDate: serviceDate);

  // ─── Writes (never queued, never optimistic) ───────────────────────────────

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
    final id = await _remote.createRoute(
      query: query,
      name: name,
      shift: shift,
      direction: direction,
      code: code,
      defaultDepartureTime: defaultDepartureTime,
      defaultReturnTime: defaultReturnTime,
      distanceM: distanceM,
    );
    _invalidateRoutes(query);
    return id;
  }

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
    await _remote.updateRoute(
      query: query,
      routeId: routeId,
      name: name,
      code: code,
      shift: shift,
      direction: direction,
      defaultDepartureTime: defaultDepartureTime,
      defaultReturnTime: defaultReturnTime,
      distanceM: distanceM,
    );
    _invalidateRoutes(query);
  }

  Future<void> activateRoute({
    required RepositoryQuery query,
    required String routeId,
  }) async {
    await _remote.activateRoute(query: query, routeId: routeId);
    _invalidateRoutes(query);
  }

  Future<int> deactivateRoute({
    required RepositoryQuery query,
    required String routeId,
  }) async {
    final stillAllocated =
        await _remote.deactivateRoute(query: query, routeId: routeId);
    _invalidateRoutes(query);
    return stillAllocated;
  }

  Future<void> deleteRoute({
    required RepositoryQuery query,
    required String routeId,
  }) async {
    await _remote.deleteRoute(query: query, routeId: routeId);
    _invalidateRoutes(query);
  }

  Future<String> createStop({
    required RepositoryQuery query,
    required String name,
    required GeoPoint location,
    int geofenceRadiusM = 100,
    String addressText = '',
    String landmark = '',
  }) async {
    final id = await _remote.createStop(
      query: query,
      name: name,
      location: location,
      geofenceRadiusM: geofenceRadiusM,
      addressText: addressText,
      landmark: landmark,
    );
    _invalidateStops(query);
    return id;
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
    await _remote.updateStop(
      query: query,
      stopId: stopId,
      name: name,
      location: location,
      geofenceRadiusM: geofenceRadiusM,
      addressText: addressText,
      landmark: landmark,
    );
    _invalidateStops(query);
    // A stop's location change can flip a route from unpublishable to ready.
    _invalidateRoutes(query);
  }

  Future<void> deleteStop({
    required RepositoryQuery query,
    required String stopId,
  }) async {
    await _remote.deleteStop(query: query, stopId: stopId);
    _invalidateStops(query);
    _invalidateRoutes(query);
  }

  Future<void> attachStop({
    required RepositoryQuery query,
    required String routeId,
    required String stopId,
    StopTime? pickupTime,
    StopTime? dropTime,
    int dwellSeconds = 60,
  }) async {
    await _remote.attachStop(
      query: query,
      routeId: routeId,
      stopId: stopId,
      pickupTime: pickupTime,
      dropTime: dropTime,
      dwellSeconds: dwellSeconds,
    );
    _invalidateRoutes(query);
  }

  Future<void> updateRouteStop({
    required RepositoryQuery query,
    required String routeId,
    required String stopId,
    StopTime? pickupTime,
    StopTime? dropTime,
    int? dwellSeconds,
  }) async {
    await _remote.updateRouteStop(
      query: query,
      routeId: routeId,
      stopId: stopId,
      pickupTime: pickupTime,
      dropTime: dropTime,
      dwellSeconds: dwellSeconds,
    );
    _invalidateRoutes(query);
  }

  Future<void> detachStop({
    required RepositoryQuery query,
    required String routeId,
    required String stopId,
  }) async {
    await _remote.detachStop(query: query, routeId: routeId, stopId: stopId);
    _invalidateRoutes(query);
  }

  Future<void> reorderStops({
    required RepositoryQuery query,
    required String routeId,
    required List<String> stopOrder,
  }) async {
    await _remote.reorderStops(
      query: query,
      routeId: routeId,
      stopOrder: stopOrder,
    );
    _invalidateRoutes(query);
  }

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
    final assignment = await _remote.setAssignment(
      query: query,
      routeId: routeId,
      vehicleId: vehicleId,
      driverId: driverId,
      attendantId: attendantId,
      effectiveFrom: effectiveFrom,
      reason: reason,
      allowNonCompliant: allowNonCompliant,
    );
    _invalidateRoutes(query);
    return assignment;
  }

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
    final result = await _remote.substituteAssignment(
      query: query,
      routeId: routeId,
      reason: reason,
      vehicleId: vehicleId,
      driverId: driverId,
      attendantId: attendantId,
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
      allowNonCompliant: allowNonCompliant,
    );
    _invalidateRoutes(query);
    return result;
  }

  Future<int> cancelSubstitute({
    required RepositoryQuery query,
    required String assignmentId,
  }) async {
    final rebound =
        await _remote.cancelSubstitute(query: query, assignmentId: assignmentId);
    _invalidateRoutes(query);
    return rebound;
  }

  Future<List<UnstaffedRouteV2>> setDriverAvailability({
    required RepositoryQuery query,
    required String driverId,
    required String fromDate,
    required String toDate,
    String kind = 'leave',
    String reason = '',
  }) async {
    final affected = await _remote.setDriverAvailability(
      query: query,
      driverId: driverId,
      fromDate: fromDate,
      toDate: toDate,
      kind: kind,
      reason: reason,
    );
    _invalidateRoutes(query);
    return affected;
  }

  Future<void> deleteVehicle({
    required RepositoryQuery query,
    required String vehicleId,
  }) async {
    await _remote.deleteVehicle(query: query, vehicleId: vehicleId);
    _invalidateRoutes(query);
  }

  Future<void> deleteDriver({
    required RepositoryQuery query,
    required String driverId,
  }) async {
    await _remote.deleteDriver(query: query, driverId: driverId);
    _invalidateRoutes(query);
  }

  /// A successful write makes the cache wrong, so it is dropped rather than
  /// patched. Patching would risk serving a locally-invented shape as if the
  /// backend had confirmed it — the class of lie BUS-008 removed.
  void _invalidateRoutes(RepositoryQuery query) => _routeCache.remove(_key(query));
  void _invalidateStops(RepositoryQuery query) => _stopCache.remove(_key(query));
}

class _CachedRoutes {
  _CachedRoutes(this.routes, this.at);
  final List<TransportRouteV2> routes;
  final DateTime at;
}

class _CachedStops {
  _CachedStops(this.stops, this.at);
  final List<TransportStopV2> stops;
  final DateTime at;
}

/// A read result that states whether it came from cache. The UI MUST surface
/// staleness — showing cached routes as if live is how an admin ends up
/// configuring against data that no longer exists.
class RoutesResult {
  const RoutesResult({
    required this.routes,
    required this.isStale,
    required this.cachedAt,
  });

  final List<TransportRouteV2> routes;
  final bool isStale;
  final DateTime? cachedAt;
}

class StopsResult {
  const StopsResult({
    required this.stops,
    required this.isStale,
    required this.cachedAt,
  });

  final List<TransportStopV2> stops;
  final bool isStale;
  final DateTime? cachedAt;
}
