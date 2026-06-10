import '../../../features/finance/inventory_finance/inventory_finance_models.dart';
import '../../../features/finance/inventory_finance/inventory_finance_requests.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Inventory–finance reconciliation and v7.2 write operations.
abstract class InventoryFinanceRepository {
  Future<InventoryFinanceReconciliationDashboard> getReconciliationDashboard({
    required RepositoryQuery query,
  });

  Future<List<InventoryFinanceTimelineEntry>> getTimeline({
    required RepositoryQuery query,
  });

  Future<PaginatedResult<InventoryFinanceGoodsReceiptSummary>> getGoodsReceipts({
    required RepositoryQuery query,
  });

  Future<InventoryFinanceGoodsReceiptDetail?> getGoodsReceipt({
    required RepositoryQuery query,
    required String goodsReceiptId,
  });

  Future<PaginatedResult<InventoryFinancePosting>> getPostings({
    required RepositoryQuery query,
  });

  Future<PaginatedResult<InventoryFinanceVendor>> getVendors({
    required RepositoryQuery query,
  });

  Future<PaginatedResult<InventoryFinancePurchaseOrderSummary>> getPurchaseOrders({
    required RepositoryQuery query,
  });

  Future<InventoryFinancePurchaseOrder?> getPurchaseOrder({
    required RepositoryQuery query,
    required String purchaseOrderId,
  });

  Future<List<InventoryFinanceVendorTransaction>> getVendorTransactions({
    required RepositoryQuery query,
    required String vendorId,
  });

  Future<List<InventoryFinanceStockValuation>> getStockValuation({
    required RepositoryQuery query,
  });

  Future<InventoryFinanceVendor> createVendor({
    required RepositoryQuery query,
    required CreateInventoryVendorRequest request,
  });

  Future<InventoryFinancePurchaseOrderSummary> createPurchaseOrder({
    required RepositoryQuery query,
    required CreateInventoryPurchaseOrderRequest request,
  });

  Future<InventoryFinanceApproveResult> approvePurchaseOrder({
    required RepositoryQuery query,
    required String purchaseOrderId,
  });

  Future<InventoryFinanceReceiveResult> receiveGoods({
    required RepositoryQuery query,
    required String purchaseOrderId,
    required ReceiveInventoryGoodsRequest request,
  });
}
