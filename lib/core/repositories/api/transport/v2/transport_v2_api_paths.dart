/// REST paths for the Transport v2 API.
///
/// Mounted under `/transport/v2/*`, matched by the backend router BEFORE the
/// legacy handlers so a v2 call can never reach one that writes to the JSONB
/// entity store (roadmap hard gate). BUS-031 removes the legacy paths once every
/// reader is on v2.
abstract final class TransportV2ApiPaths {
  static const String base = '/transport/v2';

  // Routes
  static const String routes = '$base/routes';
  static const String unstaffedRoutes = '$base/routes/unstaffed';
  static String route(String id) => '$base/routes/$id';
  static String activateRoute(String id) => '$base/routes/$id/activate';
  static String deactivateRoute(String id) => '$base/routes/$id/deactivate';
  static String routeReadiness(String id) => '$base/routes/$id/readiness';

  /// BUS-043/048 — the assignment endpoint that did not exist pre-v2.
  static String routeAssignment(String id) => '$base/routes/$id/assignment';

  /// BUS-046/051 — bounded substitution; the permanent assignment is untouched.
  static String routeSubstitute(String id) => '$base/routes/$id/substitute';

  /// BUS-044 — the revived capacity guard, probeable before a save.
  static String routeCapacityCheck(String id) => '$base/routes/$id/capacity-check';

  // Stops (school-owned, shared across AM/PM routes)
  static const String stops = '$base/stops';
  static String stop(String id) => '$base/stops/$id';

  // Route ↔ stop junction
  static String routeStops(String routeId) => '$base/routes/$routeId/stops';
  static String routeStop(String routeId, String stopId) =>
      '$base/routes/$routeId/stops/$stopId';
  static String routeStopsReorder(String routeId) =>
      '$base/routes/$routeId/stops/reorder';

  // Fleet & crew
  static const String vehicles = '$base/vehicles';
  static const String drivers = '$base/drivers';
  static String vehicle(String id) => '$base/vehicles/$id';
  static String driver(String id) => '$base/drivers/$id';
  static String driverAvailability(String id) => '$base/drivers/$id/availability';
  static String assignment(String id) => '$base/assignments/$id';
}
