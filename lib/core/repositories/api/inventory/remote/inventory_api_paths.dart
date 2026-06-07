/// REST paths for the Inventory API module.
abstract final class InventoryApiPaths {
  static const String base = '/inventory';

  static const String dashboard = '$base/dashboard';
  static const String assets = '$base/assets';
  static const String categories = '$base/categories';
  static const String allocations = '$base/allocations';
  static const String maintenance = '$base/maintenance';
  static const String procurement = '$base/procurement';
  static const String vendors = '$base/vendors';
  static const String reports = '$base/reports';
}
