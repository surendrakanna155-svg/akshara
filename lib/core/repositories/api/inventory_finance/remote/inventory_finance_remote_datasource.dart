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
