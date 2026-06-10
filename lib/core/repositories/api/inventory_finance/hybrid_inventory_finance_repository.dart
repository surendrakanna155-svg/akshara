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
}
