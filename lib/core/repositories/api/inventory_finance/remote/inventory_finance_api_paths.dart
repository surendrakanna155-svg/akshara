/// REST paths for inventory–finance v7.2 integration.
abstract final class InventoryFinanceApiPaths {
  static const String reconciliationDashboard =
      '/finance/inventory-reconciliation/dashboard';
  static const String reconciliationTimeline =
      '/finance/inventory-reconciliation/timeline';
  static const String goodsReceipts =
      '/finance/inventory-reconciliation/goods-receipts';
  static String goodsReceipt(String id) => '$goodsReceipts/$id';
  static const String postings =
      '/finance/inventory-reconciliation/postings';
  static String vendorTransactions(String vendorId) =>
      '/finance/inventory-reconciliation/vendors/$vendorId/transactions';

  static const String vendorCatalog = '/inventory/vendors/catalog';
  static const String procurementOrders = '/inventory/procurement/orders';
  static String procurementOrder(String id) => '$procurementOrders/$id';
  static String approvePurchaseOrder(String id) =>
      '$procurementOrders/$id/approve';
  static String receiveGoods(String id) => '$procurementOrders/$id/receive';

  /// INV-5 — GRN register on the inventory surface (viewInventory-gated),
  /// unlike [goodsReceipts] which rides the viewFinance reconciliation surface.
  static const String procurementGrns = '/inventory/procurement/grns';
  static const String stockValuation = '/inventory/stock/valuation';

  // ── INV-1..7 — Store STOCK module ──
  static const String stockIssue = '/inventory/stock/issue';
  static const String stockAdjust = '/inventory/stock/adjust';
  static const String stockAdjustments = '/inventory/stock/adjustments';
  static String approveStockAdjustment(String id) =>
      '$stockAdjustments/$id/approve';
  static String rejectStockAdjustment(String id) =>
      '$stockAdjustments/$id/reject';
  static const String stockCount = '/inventory/stock/count';
  static const String stockItems = '/inventory/stock/items';
  static const String stockRegister = '/inventory/stock/register';
  static const String lowStock = '/inventory/stock/low-stock';
}
