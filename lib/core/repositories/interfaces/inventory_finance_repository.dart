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

  // ── INV-1..7 — Store STOCK module ──

  /// INV-1 — post an issue slip (posted immediately; rejects below on-hand with
  /// 422 InsufficientStock; idempotent on issueNumber).
  Future<StockIssue> issueStock({
    required RepositoryQuery query,
    required IssueStockRequest request,
  });

  /// INV-3 — record a manual adjustment. `adjust_in`/`opening` apply now;
  /// `adjust_out` returns a pending maker-checker adjustment.
  Future<StockAdjustmentResult> adjustStock({
    required RepositoryQuery query,
    required AdjustStockRequest request,
  });

  /// Maker-checker approve of a value-reducing adjustment. The approver must
  /// differ from the maker (409 SELF_APPROVE_DENIED on self-approve).
  Future<StockAdjustmentDecision> approveStockAdjustment({
    required RepositoryQuery query,
    required String adjustmentId,
    String? comment,
  });

  /// Maker-checker reject of a value-reducing adjustment (no stock change).
  Future<StockAdjustmentDecision> rejectStockAdjustment({
    required RepositoryQuery query,
    required String adjustmentId,
    String? comment,
  });

  /// Pending value-reducing adjustments awaiting a checker.
  Future<List<StockAdjustment>> listPendingAdjustments({
    required RepositoryQuery query,
  });

  /// INV-6 — post a physical count session (positive variance applies; negative
  /// variance returns a pending adjustment).
  Future<StockCountResult> recordStockCount({
    required RepositoryQuery query,
    required RecordStockCountRequest request,
  });

  /// INV-2 — upsert a consumable/asset registry item + reorder level.
  Future<StockItem> upsertStockItem({
    required RepositoryQuery query,
    required UpsertStockItemRequest request,
  });

  /// INV-2 — the consumable/asset registry.
  Future<List<StockItem>> listStockItems({
    required RepositoryQuery query,
  });

  /// INV-4 — items where qty < reorder_level, each carrying a recommended
  /// top-up quantity + default vendor for raising a PO.
  Future<List<LowStockRow>> listLowStock({
    required RepositoryQuery query,
  });

  /// INV-5 — the immutable stock register (ledger), newest first.
  Future<List<StockRegisterRow>> listStockRegister({
    required RepositoryQuery query,
    String? sku,
  });

  /// INV-5 — the GRN (goods received) register, newest first. Same rows as
  /// [getGoodsReceipts] but served from the viewInventory-gated inventory
  /// endpoint so store staff can list/export without a finance grant.
  Future<List<InventoryFinanceGoodsReceiptSummary>> listGrns({
    required RepositoryQuery query,
  });
}
