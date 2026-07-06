import '../../interfaces/inventory_finance_repository.dart';
import '../../pagination_helpers.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../../features/finance/inventory_finance/inventory_finance_models.dart';
import '../../../../../features/finance/inventory_finance/inventory_finance_requests.dart';
import 'mapper/inventory_finance_mapper.dart';
import 'remote/inventory_finance_remote_datasource.dart';

class ApiInventoryFinanceRepository implements InventoryFinanceRepository {
  ApiInventoryFinanceRepository({
    required InventoryFinanceRemoteDataSource remote,
    InventoryFinanceMapper mapper = const InventoryFinanceMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final InventoryFinanceRemoteDataSource _remote;
  final InventoryFinanceMapper _mapper;

  @override
  Future<InventoryFinanceReconciliationDashboard> getReconciliationDashboard({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchReconciliationDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<List<InventoryFinanceTimelineEntry>> getTimeline({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.fetchTimeline(query: query);
    return _mapper.toTimeline(items);
  }

  @override
  Future<PaginatedResult<InventoryFinanceGoodsReceiptSummary>> getGoodsReceipts({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.fetchGoodsReceipts(query: query);
    return paginateList(_mapper.toGoodsReceiptSummaries(items), query);
  }

  @override
  Future<InventoryFinanceGoodsReceiptDetail?> getGoodsReceipt({
    required RepositoryQuery query,
    required String goodsReceiptId,
  }) async {
    final dto = await _remote.fetchGoodsReceipt(
      query: query,
      goodsReceiptId: goodsReceiptId,
    );
    return _mapper.toGoodsReceiptDetail(dto);
  }

  @override
  Future<PaginatedResult<InventoryFinancePosting>> getPostings({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.fetchPostings(query: query);
    return paginateList(_mapper.toPostings(items), query);
  }

  @override
  Future<PaginatedResult<InventoryFinanceVendor>> getVendors({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.fetchVendors(query: query);
    return paginateList(_mapper.toVendors(items), query);
  }

  @override
  Future<PaginatedResult<InventoryFinancePurchaseOrderSummary>> getPurchaseOrders({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.fetchPurchaseOrders(query: query);
    return paginateList(_mapper.toPurchaseOrderSummaries(items), query);
  }

  @override
  Future<InventoryFinancePurchaseOrder?> getPurchaseOrder({
    required RepositoryQuery query,
    required String purchaseOrderId,
  }) async {
    final dto = await _remote.fetchPurchaseOrder(
      query: query,
      purchaseOrderId: purchaseOrderId,
    );
    return _mapper.toPurchaseOrderDetail(dto);
  }

  @override
  Future<List<InventoryFinanceVendorTransaction>> getVendorTransactions({
    required RepositoryQuery query,
    required String vendorId,
  }) async {
    final items = await _remote.fetchVendorTransactions(
      query: query,
      vendorId: vendorId,
    );
    return _mapper.toVendorTransactions(items);
  }

  @override
  Future<List<InventoryFinanceStockValuation>> getStockValuation({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.fetchStockValuation(query: query);
    return _mapper.toStockValuation(items);
  }

  @override
  Future<InventoryFinanceVendor> createVendor({
    required RepositoryQuery query,
    required CreateInventoryVendorRequest request,
  }) async {
    final dto = await _remote.createVendor(query: query, request: request);
    return _mapper.toVendor(dto);
  }

  @override
  Future<InventoryFinancePurchaseOrderSummary> createPurchaseOrder({
    required RepositoryQuery query,
    required CreateInventoryPurchaseOrderRequest request,
  }) async {
    final dto = await _remote.createPurchaseOrder(query: query, request: request);
    return _mapper.toPurchaseOrderSummaries([dto]).first;
  }

  @override
  Future<InventoryFinanceApproveResult> approvePurchaseOrder({
    required RepositoryQuery query,
    required String purchaseOrderId,
  }) async {
    final data = await _remote.approvePurchaseOrder(
      query: query,
      purchaseOrderId: purchaseOrderId,
    );
    return _mapper.toApproveResult(data);
  }

  @override
  Future<InventoryFinanceReceiveResult> receiveGoods({
    required RepositoryQuery query,
    required String purchaseOrderId,
    required ReceiveInventoryGoodsRequest request,
  }) async {
    final data = await _remote.receiveGoods(
      query: query,
      purchaseOrderId: purchaseOrderId,
      request: request,
    );
    return _mapper.toReceiveResult(data);
  }

  // ── INV-1..7 — Store STOCK module ──

  @override
  Future<StockIssue> issueStock({
    required RepositoryQuery query,
    required IssueStockRequest request,
  }) async {
    final dto = await _remote.issueStock(query: query, request: request);
    return _mapper.toStockIssue(dto);
  }

  @override
  Future<StockAdjustmentResult> adjustStock({
    required RepositoryQuery query,
    required AdjustStockRequest request,
  }) async {
    final dto = await _remote.adjustStock(query: query, request: request);
    return _mapper.toStockAdjustmentResult(dto);
  }

  @override
  Future<StockAdjustmentDecision> approveStockAdjustment({
    required RepositoryQuery query,
    required String adjustmentId,
    String? comment,
  }) async {
    final dto = await _remote.approveStockAdjustment(
      query: query,
      adjustmentId: adjustmentId,
      comment: comment,
    );
    return _mapper.toStockAdjustmentDecision(dto);
  }

  @override
  Future<StockAdjustmentDecision> rejectStockAdjustment({
    required RepositoryQuery query,
    required String adjustmentId,
    String? comment,
  }) async {
    final dto = await _remote.rejectStockAdjustment(
      query: query,
      adjustmentId: adjustmentId,
      comment: comment,
    );
    return _mapper.toStockAdjustmentDecision(dto);
  }

  @override
  Future<List<StockAdjustment>> listPendingAdjustments({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.listPendingAdjustments(query: query);
    return _mapper.toStockAdjustments(items);
  }

  @override
  Future<StockCountResult> recordStockCount({
    required RepositoryQuery query,
    required RecordStockCountRequest request,
  }) async {
    final dto = await _remote.recordStockCount(query: query, request: request);
    return _mapper.toStockCountResult(dto);
  }

  @override
  Future<StockItem> upsertStockItem({
    required RepositoryQuery query,
    required UpsertStockItemRequest request,
  }) async {
    final dto = await _remote.upsertStockItem(query: query, request: request);
    return _mapper.toStockItem(dto);
  }

  @override
  Future<List<StockItem>> listStockItems({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.listStockItems(query: query);
    return _mapper.toStockItems(items);
  }

  @override
  Future<List<LowStockRow>> listLowStock({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.listLowStock(query: query);
    return _mapper.toLowStockRows(items);
  }

  @override
  Future<List<StockRegisterRow>> listStockRegister({
    required RepositoryQuery query,
    String? sku,
  }) async {
    final items = await _remote.listStockRegister(query: query, sku: sku);
    return _mapper.toStockRegisterRows(items);
  }

  @override
  Future<List<InventoryFinanceGoodsReceiptSummary>> listGrns({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.fetchGrnRegister(query: query);
    return _mapper.toGoodsReceiptSummaries(items);
  }
}
