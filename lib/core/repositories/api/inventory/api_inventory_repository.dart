import '../../interfaces/inventory_repository.dart';
import '../../pagination_helpers.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/inventory/inventory_models.dart';
import '../../../../features/inventory/inventory_requests.dart';
import '../../../../features/inventory/intelligence/inventory_intelligence_models.dart';
import '../api_exception.dart';
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
    throw ApiNotConnectedException(
        'InventoryRepository', 'createProcurementOrder');
  }

  @override
  Future<InventoryProcurementOrder> approveProcurementOrder({
    required RepositoryQuery query,
    required String orderId,
  }) async {
    throw ApiNotConnectedException(
        'InventoryRepository', 'approveProcurementOrder');
  }

  @override
  Future<InventoryProcurementOrder> recordProcurementReceiveHandoff({
    required RepositoryQuery query,
    required String orderId,
  }) async {
    throw ApiNotConnectedException(
      'InventoryRepository',
      'recordProcurementReceiveHandoff',
    );
  }
}
