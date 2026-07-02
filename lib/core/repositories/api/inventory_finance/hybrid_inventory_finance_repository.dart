import '../../interfaces/inventory_finance_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/finance/inventory_finance/inventory_finance_models.dart';
import '../../../../features/finance/inventory_finance/inventory_finance_requests.dart';
import 'api_inventory_finance_repository.dart';

/// Routes inventory–finance operations to [ApiInventoryFinanceRepository].
class HybridInventoryFinanceRepository implements InventoryFinanceRepository {
  HybridInventoryFinanceRepository({required ApiInventoryFinanceRepository api})
      : _api = api;

  final ApiInventoryFinanceRepository _api;

  @override
  Future<InventoryFinanceReconciliationDashboard> getReconciliationDashboard({
    required RepositoryQuery query,
  }) =>
      _api.getReconciliationDashboard(query: query);

  @override
  Future<List<InventoryFinanceTimelineEntry>> getTimeline({
    required RepositoryQuery query,
  }) =>
      _api.getTimeline(query: query);

  @override
  Future<PaginatedResult<InventoryFinanceGoodsReceiptSummary>> getGoodsReceipts({
    required RepositoryQuery query,
  }) =>
      _api.getGoodsReceipts(query: query);

  @override
  Future<InventoryFinanceGoodsReceiptDetail?> getGoodsReceipt({
    required RepositoryQuery query,
    required String goodsReceiptId,
  }) =>
      _api.getGoodsReceipt(query: query, goodsReceiptId: goodsReceiptId);

  @override
  Future<PaginatedResult<InventoryFinancePosting>> getPostings({
    required RepositoryQuery query,
  }) =>
      _api.getPostings(query: query);

  @override
  Future<PaginatedResult<InventoryFinanceVendor>> getVendors({
    required RepositoryQuery query,
  }) =>
      _api.getVendors(query: query);

  @override
  Future<PaginatedResult<InventoryFinancePurchaseOrderSummary>> getPurchaseOrders({
    required RepositoryQuery query,
  }) =>
      _api.getPurchaseOrders(query: query);

  @override
  Future<InventoryFinancePurchaseOrder?> getPurchaseOrder({
    required RepositoryQuery query,
    required String purchaseOrderId,
  }) =>
      _api.getPurchaseOrder(query: query, purchaseOrderId: purchaseOrderId);

  @override
  Future<List<InventoryFinanceVendorTransaction>> getVendorTransactions({
    required RepositoryQuery query,
    required String vendorId,
  }) =>
      _api.getVendorTransactions(query: query, vendorId: vendorId);

  @override
  Future<List<InventoryFinanceStockValuation>> getStockValuation({
    required RepositoryQuery query,
  }) =>
      _api.getStockValuation(query: query);

  @override
  Future<InventoryFinanceVendor> createVendor({
    required RepositoryQuery query,
    required CreateInventoryVendorRequest request,
  }) =>
      _api.createVendor(query: query, request: request);

  @override
  Future<InventoryFinancePurchaseOrderSummary> createPurchaseOrder({
    required RepositoryQuery query,
    required CreateInventoryPurchaseOrderRequest request,
  }) =>
      _api.createPurchaseOrder(query: query, request: request);

  @override
  Future<InventoryFinanceApproveResult> approvePurchaseOrder({
    required RepositoryQuery query,
    required String purchaseOrderId,
  }) =>
      _api.approvePurchaseOrder(query: query, purchaseOrderId: purchaseOrderId);

  @override
  Future<InventoryFinanceReceiveResult> receiveGoods({
    required RepositoryQuery query,
    required String purchaseOrderId,
    required ReceiveInventoryGoodsRequest request,
  }) =>
      _api.receiveGoods(
        query: query,
        purchaseOrderId: purchaseOrderId,
        request: request,
      );

  // ── INV-1..7 — Store STOCK module ──

  @override
  Future<StockIssue> issueStock({
    required RepositoryQuery query,
    required IssueStockRequest request,
  }) =>
      _api.issueStock(query: query, request: request);

  @override
  Future<StockAdjustmentResult> adjustStock({
    required RepositoryQuery query,
    required AdjustStockRequest request,
  }) =>
      _api.adjustStock(query: query, request: request);

  @override
  Future<StockAdjustmentDecision> approveStockAdjustment({
    required RepositoryQuery query,
    required String adjustmentId,
    String? comment,
  }) =>
      _api.approveStockAdjustment(
        query: query,
        adjustmentId: adjustmentId,
        comment: comment,
      );

  @override
  Future<StockAdjustmentDecision> rejectStockAdjustment({
    required RepositoryQuery query,
    required String adjustmentId,
    String? comment,
  }) =>
      _api.rejectStockAdjustment(
        query: query,
        adjustmentId: adjustmentId,
        comment: comment,
      );

  @override
  Future<List<StockAdjustment>> listPendingAdjustments({
    required RepositoryQuery query,
  }) =>
      _api.listPendingAdjustments(query: query);

  @override
  Future<StockCountResult> recordStockCount({
    required RepositoryQuery query,
    required RecordStockCountRequest request,
  }) =>
      _api.recordStockCount(query: query, request: request);

  @override
  Future<StockItem> upsertStockItem({
    required RepositoryQuery query,
    required UpsertStockItemRequest request,
  }) =>
      _api.upsertStockItem(query: query, request: request);

  @override
  Future<List<StockItem>> listStockItems({
    required RepositoryQuery query,
  }) =>
      _api.listStockItems(query: query);

  @override
  Future<List<LowStockRow>> listLowStock({
    required RepositoryQuery query,
  }) =>
      _api.listLowStock(query: query);

  @override
  Future<List<StockRegisterRow>> listStockRegister({
    required RepositoryQuery query,
    String? sku,
  }) =>
      _api.listStockRegister(query: query, sku: sku);
}
