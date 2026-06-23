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

  static String activateRoute(String id) => '$base/routes/$id/activate';
  static String transferAllocation(String id) => '$base/allocations/$id/transfer';
  static String allocation(String id) => '$base/allocations/$id';
}
