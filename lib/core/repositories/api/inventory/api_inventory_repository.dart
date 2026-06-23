import '../../interfaces/inventory_repository.dart';
import '../../pagination_helpers.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/inventory/inventory_models.dart';
import '../../../../features/inventory/inventory_requests.dart';
import '../../../../features/inventory/intelligence/inventory_intelligence_models.dart';
import 'mapper/inventory_intelligence_mapper.dart';
import 'mapper/inventory_mapper.dart';
import 'remote/inventory_remote_datasource.dart';

/// API implementation of [InventoryRepository] — enabled via [inventoryApiEnabledProvider].
class ApiInventoryRepository implements InventoryRepository {
  ApiInventoryRepository({
    required InventoryRemoteDataSource remote,
    InventoryMapper mapper = const InventoryMapper(),
    InventoryIntelligenceMapper intelligenceMapper =
        const InventoryIntelligenceMapper(),
  })  : _remote = remote,
        _mapper = mapper,
        _intelligenceMapper = intelligenceMapper;

  final InventoryRemoteDataSource _remote;
  final InventoryMapper _mapper;
  final InventoryIntelligenceMapper _intelligenceMapper;

  @override
  Future<InventoryDashboardData> getDashboard(
      {required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<PaginatedResult<InventoryAsset>> getAssets(
      {required RepositoryQuery query}) async {
    final dto = await _remote.fetchAssets(query: query);
    return paginateList(_mapper.toAssets(dto), query);
  }

  @override
  Future<PaginatedResult<InventoryCategory>> getCategories(
      {required RepositoryQuery query}) async {
    final dto = await _remote.fetchCategories(query: query);
    return paginateList(_mapper.toCategories(dto), query);
  }

  @override
  Future<PaginatedResult<InventoryAllocation>> getAllocations({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchAllocations(query: query);
    return paginateList(_mapper.toAllocations(dto), query);
  }

  @override
  Future<PaginatedResult<InventoryMaintenanceRecord>> getMaintenanceRecords({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchMaintenanceRecords(query: query);
    return paginateList(_mapper.toMaintenanceRecords(dto), query);
  }

  @override
  Future<PaginatedResult<InventoryProcurementOrder>> getProcurementOrders({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchProcurementOrders(query: query);
    return paginateList(_mapper.toProcurementOrders(dto), query);
  }

  @override
  Future<PaginatedResult<InventoryVendor>> getVendors(
      {required RepositoryQuery query}) async {
    final dto = await _remote.fetchVendors(query: query);
    return paginateList(_mapper.toVendors(dto), query);
  }

  @override
  Future<InventoryReportsData> getReports(
      {required RepositoryQuery query}) async {
    final dto = await _remote.fetchReports(query: query);
    return _mapper.toReports(dto);
  }

  @override
  Future<InventoryCopilotData> getInventoryCopilot(
      {required RepositoryQuery query}) async {
    final dto = await _remote.fetchInventoryCopilot(query: query);
    return _intelligenceMapper.toCopilot(dto);
  }

  @override
  Future<AssetLifecycleData> getAssetLifecycle(
      {required RepositoryQuery query}) async {
    final dto = await _remote.fetchAssetLifecycle(query: query);
    return _intelligenceMapper.toLifecycle(dto);
  }

  @override
  Future<ProcurementWorkflowData> getProcurementWorkflow(
      {required RepositoryQuery query}) async {
    final dto = await _remote.fetchProcurementWorkflow(query: query);
    return _intelligenceMapper.toProcurementWorkflow(dto);
  }

  @override
  Future<AssetLifecycleEvent> recordAssetLifecycleEvent({
    required RepositoryQuery query,
    required RecordAssetLifecycleEventRequest request,
  }) async {
    final dto = await _remote.recordAssetLifecycleEvent(
      query: query,
      body: {
        'assetId': request.assetId,
        'eventType': request.eventType.name,
        if (request.assetTag != null) 'assetTag': request.assetTag,
        if (request.notes != null) 'notes': request.notes,
      },
    );
    return _intelligenceMapper.toLifecycleEvent(dto);
  }

  @override
  Future<InventoryProcurementOrder> createProcurementOrder({
    required RepositoryQuery query,
    required CreateInventoryProcurementOrderRequest request,
  }) async {
    // The server (POST /inventory/procurement/orders) requires a vendorId,
    // a poNumber, and structured lines [{sku, description, quantity,
    // unitCost}]. The app request carries free-text vendorName/items and a
    // total amount, so we translate it into a single synthetic line whose
    // unit cost is the requested total.
    final poNumber = request.poNumber?.trim().isNotEmpty == true
        ? request.poNumber!.trim()
        : 'PO-${DateTime.now().millisecondsSinceEpoch}';
    final unitCost = _parseAmount(request.totalAmount);
    final description =
        request.items.trim().isEmpty ? 'Procurement item' : request.items.trim();
    final row = await _remote.createProcurementOrder(
      query: query,
      body: {
        'vendorId': request.vendorName.trim(),
        'poNumber': poNumber,
        'lines': [
          {
            'sku': 'GEN-${poNumber.toUpperCase()}',
            'description': description,
            'quantity': 1,
            'unitCost': unitCost,
          },
        ],
      },
    );
    return _mapper.toProcurementOrderFromServerRow(
      row,
      context: {
        'vendorName': request.vendorName,
        'items': request.items,
        'totalAmount': request.totalAmount,
        'expectedDelivery': request.expectedDelivery,
        'requestedBy': request.requestedBy,
        'financePoId': request.financePoId,
        'poNumber': poNumber,
      },
    );
  }

  @override
  Future<InventoryProcurementOrder> approveProcurementOrder({
    required RepositoryQuery query,
    required String orderId,
  }) async {
    // Envelope data is { purchaseOrder, apCommitmentId, financePostingId }.
    final data = await _remote.approveProcurementOrder(
      query: query,
      orderId: orderId,
    );
    final po = data['purchaseOrder'] as Map<String, dynamic>? ?? const {};
    return _mapper.toProcurementOrderFromServerRow(
      po,
      context: {
        'financePoId': data['apCommitmentId'] as String?,
      },
    );
  }

  @override
  Future<InventoryProcurementOrder> recordProcurementReceiveHandoff({
    required RepositoryQuery query,
    required String orderId,
  }) async {
    // The receive endpoint requires line-level received quantities, which the
    // handoff action does not carry. We fully receive every outstanding line
    // by reading the PO detail first, then post the receipt. The receive
    // response only returns the GRN summary, so we re-fetch the PO detail to
    // return the updated order.
    final detail = await _remote.fetchProcurementOrderDetail(
      query: query,
      orderId: orderId,
    );
    final lines = (detail['lines'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((line) {
      final quantity = (line['quantity'] as num?)?.toInt() ?? 0;
      final received = (line['quantityReceived'] as num?)?.toInt() ?? 0;
      return {
        'purchaseOrderLineId': line['id'] as String? ?? '',
        'quantityReceived': quantity - received,
      };
    }).where((line) => (line['quantityReceived'] as int) > 0).toList();

    await _remote.receiveProcurementOrder(
      query: query,
      orderId: orderId,
      body: {'lines': lines},
    );

    final updated = await _remote.fetchProcurementOrderDetail(
      query: query,
      orderId: orderId,
    );
    final po = updated['purchaseOrder'] as Map<String, dynamic>? ?? const {};
    return _mapper.toProcurementOrderFromServerRow(po);
  }

  double _parseAmount(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }
}
