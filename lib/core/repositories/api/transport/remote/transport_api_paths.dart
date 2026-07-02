/// REST paths for the Transport API module.
abstract final class TransportApiPaths {
  static const String base = '/transport';

  static const String dashboard = '$base/dashboard';
  static const String routes = '$base/routes';
  static const String vehicles = '$base/vehicles';
  static const String drivers = '$base/drivers';
  static const String allocations = '$base/allocations';
  static const String attendance = '$base/attendance';
  static const String tracking = '$base/tracking';
  static const String reports = '$base/reports';
  static const String settings = '$base/settings';
  static const String occupancyMetrics = '$base/occupancy-metrics';
  static const String notifyDelay = '$base/notify-delay';

  // TRN-5 / TRN-8 / TRN-9 collection-level writes.
  static const String allocationsBulk = '$base/allocations/bulk';
  static const String documentExpiryReminder =
      '$base/reminders/document-expiry';
  static const String demands = '$base/demands';

  static String activateRoute(String id) => '$base/routes/$id/activate';
  static String transferAllocation(String id) => '$base/allocations/$id/transfer';
  static String allocation(String id) => '$base/allocations/$id';

  // TRN-1/TRN-2 vehicle & driver CRUD.
  static String vehicle(String id) => '$base/vehicles/$id';
  static String driver(String id) => '$base/drivers/$id';

  // TRN-3 stop-wise roster.
  static String routeRoster(String routeId) => '$base/routes/$routeId/roster';

  // TRN-4 stop editor.
  static String routeStops(String routeId) => '$base/routes/$routeId/stops';
  static String routeStopsReorder(String routeId) =>
      '$base/routes/$routeId/stops/reorder';
  static String routeStop(String routeId, String stopId) =>
      '$base/routes/$routeId/stops/$stopId';
}
