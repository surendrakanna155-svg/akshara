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
  static const String intelligenceCopilot = '$base/intelligence/copilot';
  static const String intelligenceLifecycle = '$base/intelligence/lifecycle';
  static const String intelligenceLifecycleEvents = '$base/intelligence/lifecycle/events';
  static const String intelligenceProcurementWorkflow = '$base/intelligence/procurement-workflow';

  static String intelligenceProcurementAdvance(String purchaseOrderId) =>
      '$base/intelligence/procurement-workflow/$purchaseOrderId/advance';

  // Procurement order write endpoints (backed by inventory_finance_router.ts).
  static const String procurementOrders = '$base/procurement/orders';

  static String procurementOrderDetail(String id) =>
      '$base/procurement/orders/$id';

  static String approveProcurementOrder(String id) =>
      '$base/procurement/orders/$id/approve';

  static String receiveProcurementOrder(String id) =>
      '$base/procurement/orders/$id/receive';
}
