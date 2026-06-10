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
  static const String stockValuation = '/inventory/stock/valuation';
}
