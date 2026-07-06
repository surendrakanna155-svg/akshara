import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../../../../features/finance/inventory_finance/inventory_finance_requests.dart';
import '../dto/inventory_finance_dto.dart';
import 'inventory_finance_api_paths.dart';

class InventoryFinanceRemoteDataSource {
  InventoryFinanceRemoteDataSource(this._dio);

  final Dio _dio;

  Future<InventoryFinanceDashboardDto> fetchReconciliationDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.reconciliationDashboard,
      queryParameters: _queryParams(query),
    );
    return InventoryFinanceDashboardDto.fromJson(
      parseInventoryFinanceEnvelope(_responseMap(response)),
    );
  }

  Future<List<InventoryFinanceTimelineItemDto>> fetchTimeline({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.reconciliationTimeline,
      queryParameters: _queryParams(query),
    );
    final data = parseInventoryFinanceEnvelope(_responseMap(response));
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map(
          (item) => InventoryFinanceTimelineItemDto.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<InventoryFinanceGoodsReceiptSummaryDto>> fetchGoodsReceipts({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.goodsReceipts,
      queryParameters: _queryParams(query),
    );
    return parseInventoryFinanceItems(_responseMap(response))
        .map(InventoryFinanceGoodsReceiptSummaryDto.fromJson)
        .toList();
  }

  Future<InventoryFinanceGoodsReceiptDetailDto> fetchGoodsReceipt({
    required RepositoryQuery query,
    required String goodsReceiptId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.goodsReceipt(goodsReceiptId),
      queryParameters: _queryParams(query),
    );
    return InventoryFinanceGoodsReceiptDetailDto.fromJson(
      parseInventoryFinanceEnvelope(_responseMap(response)),
    );
  }

  /// INV-5 — GRN register via the viewInventory-gated inventory endpoint (same
  /// row shape as [fetchGoodsReceipts], different RBAC surface).
  Future<List<InventoryFinanceGoodsReceiptSummaryDto>> fetchGrnRegister({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.procurementGrns,
      queryParameters: _queryParams(query),
    );
    return parseInventoryFinanceItems(_responseMap(response))
        .map(InventoryFinanceGoodsReceiptSummaryDto.fromJson)
        .toList();
  }

  Future<List<InventoryFinancePostingDto>> fetchPostings({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.postings,
      queryParameters: _queryParams(query),
    );
    return parseInventoryFinanceItems(_responseMap(response))
        .map(InventoryFinancePostingDto.fromJson)
        .toList();
  }

  Future<List<InventoryFinanceVendorDto>> fetchVendors({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.vendorCatalog,
      queryParameters: _queryParams(query),
    );
    return parseInventoryFinanceItems(_responseMap(response))
        .map(InventoryFinanceVendorDto.fromJson)
        .toList();
  }

  Future<List<InventoryFinancePurchaseOrderSummaryDto>> fetchPurchaseOrders({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.procurementOrders,
      queryParameters: _queryParams(query),
    );
    return parseInventoryFinanceItems(_responseMap(response))
        .map(InventoryFinancePurchaseOrderSummaryDto.fromJson)
        .toList();
  }

  Future<InventoryFinancePurchaseOrderDetailDto> fetchPurchaseOrder({
    required RepositoryQuery query,
    required String purchaseOrderId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.procurementOrder(purchaseOrderId),
      queryParameters: _queryParams(query),
    );
    return InventoryFinancePurchaseOrderDetailDto.fromJson(
      parseInventoryFinanceEnvelope(_responseMap(response)),
    );
  }

  Future<List<InventoryFinanceVendorTransactionDto>> fetchVendorTransactions({
    required RepositoryQuery query,
    required String vendorId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.vendorTransactions(vendorId),
      queryParameters: _queryParams(query),
    );
    return parseInventoryFinanceItems(_responseMap(response))
        .map(InventoryFinanceVendorTransactionDto.fromJson)
        .toList();
  }

  Future<List<InventoryFinanceStockValuationItemDto>> fetchStockValuation({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.stockValuation,
      queryParameters: _queryParams(query),
    );
    final data = parseInventoryFinanceEnvelope(_responseMap(response));
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map(
          (item) => InventoryFinanceStockValuationItemDto.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<InventoryFinanceVendorDto> createVendor({
    required RepositoryQuery query,
    required CreateInventoryVendorRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      InventoryFinanceApiPaths.vendorCatalog,
      queryParameters: _queryParams(query),
      data: {
        'vendorCode': request.vendorCode,
        'displayName': request.displayName,
        if (request.contactPhone != null) 'contactPhone': request.contactPhone,
        if (request.contactEmail != null) 'contactEmail': request.contactEmail,
        if (request.gstin != null) 'gstin': request.gstin,
      },
    );
    return InventoryFinanceVendorDto.fromJson(
      parseInventoryFinanceEnvelope(_responseMap(response)),
    );
  }

  Future<InventoryFinancePurchaseOrderSummaryDto> createPurchaseOrder({
    required RepositoryQuery query,
    required CreateInventoryPurchaseOrderRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      InventoryFinanceApiPaths.procurementOrders,
      queryParameters: _queryParams(query),
      data: {
        'vendorId': request.vendorId,
        'poNumber': request.poNumber,
        if (request.notes != null) 'notes': request.notes,
        'lines': [
          for (final line in request.lines)
            {
              'sku': line.sku,
              'description': line.description,
              'quantity': line.quantity,
              'unitCost': line.unitCostPaise,
            },
        ],
      },
    );
    return InventoryFinancePurchaseOrderSummaryDto.fromJson(
      parseInventoryFinanceEnvelope(_responseMap(response)),
    );
  }

  Future<Map<String, dynamic>> approvePurchaseOrder({
    required RepositoryQuery query,
    required String purchaseOrderId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      InventoryFinanceApiPaths.approvePurchaseOrder(purchaseOrderId),
      queryParameters: _queryParams(query),
    );
    return parseInventoryFinanceEnvelope(_responseMap(response));
  }

  Future<Map<String, dynamic>> receiveGoods({
    required RepositoryQuery query,
    required String purchaseOrderId,
    required ReceiveInventoryGoodsRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      InventoryFinanceApiPaths.receiveGoods(purchaseOrderId),
      queryParameters: _queryParams(query),
      data: {
        'lines': [
          for (final line in request.lines)
            {
              'purchaseOrderLineId': line.purchaseOrderLineId,
              'quantityReceived': line.quantityReceived,
            },
        ],
      },
    );
    return parseInventoryFinanceEnvelope(_responseMap(response));
  }

  // ── INV-1..7 — Store STOCK module ──

  Future<StockIssueDto> issueStock({
    required RepositoryQuery query,
    required IssueStockRequest request,
  }) async {
    final issueNumber = (request.issueNumber?.trim().isNotEmpty ?? false)
        ? request.issueNumber!.trim()
        : _generatedNumber('ISS');
    final response = await _dio.post<Map<String, dynamic>>(
      InventoryFinanceApiPaths.stockIssue,
      queryParameters: _queryParams(query),
      data: {
        'issueNumber': issueNumber,
        if (request.issuedTo != null) 'issuedTo': request.issuedTo,
        if (request.reason != null) 'reason': request.reason,
        'lines': [
          {'sku': request.sku, 'quantity': request.quantity},
        ],
      },
    );
    return StockIssueDto.fromJson(
      parseInventoryFinanceEnvelope(_responseMap(response)),
    );
  }

  Future<StockAdjustmentResultDto> adjustStock({
    required RepositoryQuery query,
    required AdjustStockRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      InventoryFinanceApiPaths.stockAdjust,
      queryParameters: _queryParams(query),
      data: {
        'sku': request.sku,
        'quantity': request.qty,
        'movementType': request.movementType,
        'reason': request.reason,
        if (request.unitCostPaise != null) 'unitCost': request.unitCostPaise,
      },
    );
    return StockAdjustmentResultDto.fromJson(
      parseInventoryFinanceEnvelope(_responseMap(response)),
    );
  }

  Future<StockAdjustmentDecisionDto> approveStockAdjustment({
    required RepositoryQuery query,
    required String adjustmentId,
    String? comment,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      InventoryFinanceApiPaths.approveStockAdjustment(adjustmentId),
      queryParameters: _queryParams(query),
      data: {if (comment != null) 'comment': comment},
    );
    return StockAdjustmentDecisionDto.fromJson(
      parseInventoryFinanceEnvelope(_responseMap(response)),
    );
  }

  Future<StockAdjustmentDecisionDto> rejectStockAdjustment({
    required RepositoryQuery query,
    required String adjustmentId,
    String? comment,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      InventoryFinanceApiPaths.rejectStockAdjustment(adjustmentId),
      queryParameters: _queryParams(query),
      data: {if (comment != null) 'comment': comment},
    );
    return StockAdjustmentDecisionDto.fromJson(
      parseInventoryFinanceEnvelope(_responseMap(response)),
    );
  }

  Future<List<StockAdjustmentDto>> listPendingAdjustments({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.stockAdjustments,
      queryParameters: _queryParams(query),
    );
    return parseInventoryFinanceItems(_responseMap(response))
        .map(StockAdjustmentDto.fromJson)
        .toList();
  }

  Future<StockCountResultDto> recordStockCount({
    required RepositoryQuery query,
    required RecordStockCountRequest request,
  }) async {
    final sessionNumber = (request.sessionNumber?.trim().isNotEmpty ?? false)
        ? request.sessionNumber!.trim()
        : _generatedNumber('CNT');
    final response = await _dio.post<Map<String, dynamic>>(
      InventoryFinanceApiPaths.stockCount,
      queryParameters: _queryParams(query),
      data: {
        'sessionNumber': sessionNumber,
        if (request.notes != null) 'notes': request.notes,
        'lines': [
          {'sku': request.sku, 'countedQty': request.countedQty},
        ],
      },
    );
    return StockCountResultDto.fromJson(
      parseInventoryFinanceEnvelope(_responseMap(response)),
    );
  }

  Future<StockItemDto> upsertStockItem({
    required RepositoryQuery query,
    required UpsertStockItemRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      InventoryFinanceApiPaths.stockItems,
      queryParameters: _queryParams(query),
      data: {
        'sku': request.sku,
        if (request.itemName != null) 'itemName': request.itemName,
        'itemType': request.itemType,
        'reorderLevel': request.reorderLevel,
        if (request.unitCostPaise != null) 'unitCost': request.unitCostPaise,
      },
    );
    return StockItemDto.fromJson(
      parseInventoryFinanceEnvelope(_responseMap(response)),
    );
  }

  Future<List<StockItemDto>> listStockItems({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.stockItems,
      queryParameters: _queryParams(query),
    );
    return parseInventoryFinanceItems(_responseMap(response))
        .map(StockItemDto.fromJson)
        .toList();
  }

  Future<List<LowStockRowDto>> listLowStock({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.lowStock,
      queryParameters: _queryParams(query),
    );
    return parseInventoryFinanceItems(_responseMap(response))
        .map(LowStockRowDto.fromJson)
        .toList();
  }

  Future<List<StockRegisterRowDto>> listStockRegister({
    required RepositoryQuery query,
    String? sku,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryFinanceApiPaths.stockRegister,
      queryParameters: {
        ..._queryParams(query),
        if (sku != null && sku.trim().isNotEmpty) 'sku': sku.trim(),
      },
    );
    return parseInventoryFinanceItems(_responseMap(response))
        .map(StockRegisterRowDto.fromJson)
        .toList();
  }

  String _generatedNumber(String prefix) {
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      if (query.page > 1) 'page': query.page,
      if (query.pageSize != 20) 'pageSize': query.pageSize,
    };
  }
}
