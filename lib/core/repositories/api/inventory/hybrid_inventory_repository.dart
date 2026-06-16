import '../../interfaces/inventory_repository.dart';
import '../../mock/mock_inventory_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/inventory/inventory_models.dart';
import '../../../../features/inventory/inventory_requests.dart';
import '../../../../features/inventory/intelligence/inventory_intelligence_models.dart';
import 'api_inventory_repository.dart';
import '../hybrid_write_fallback.dart';

/// API reads with mock fallback for inventory write operations.
class HybridInventoryRepository implements InventoryRepository {
  HybridInventoryRepository({
    required ApiInventoryRepository api,
    required MockInventoryRepository mock,
  })  : _api = api,
        _mock = mock;

  final ApiInventoryRepository _api;
  final MockInventoryRepository _mock;

  @override
  Future<InventoryDashboardData> getDashboard({required RepositoryQuery query}) =>
      _api.getDashboard(query: query);

  @override
  Future<PaginatedResult<InventoryAsset>> getAssets({required RepositoryQuery query}) =>
      _api.getAssets(query: query);

  @override
  Future<PaginatedResult<InventoryCategory>> getCategories({required RepositoryQuery query}) =>
      _api.getCategories(query: query);

  @override
  Future<PaginatedResult<InventoryAllocation>> getAllocations({required RepositoryQuery query}) =>
      _api.getAllocations(query: query);

  @override
  Future<PaginatedResult<InventoryMaintenanceRecord>> getMaintenanceRecords({
    required RepositoryQuery query,
  }) =>
      _api.getMaintenanceRecords(query: query);

  @override
  Future<PaginatedResult<InventoryProcurementOrder>> getProcurementOrders({
    required RepositoryQuery query,
  }) =>
      _api.getProcurementOrders(query: query);

  @override
  Future<PaginatedResult<InventoryVendor>> getVendors({
    required RepositoryQuery query,
  }) =>
      _api.getVendors(query: query);

  @override
  Future<InventoryReportsData> getReports({required RepositoryQuery query}) =>
      _api.getReports(query: query);

  @override
  Future<InventoryCopilotData> getInventoryCopilot({
    required RepositoryQuery query,
  }) =>
      _api.getInventoryCopilot(query: query);

  @override
  Future<AssetLifecycleData> getAssetLifecycle({required RepositoryQuery query}) =>
      _api.getAssetLifecycle(query: query);

  @override
  Future<ProcurementWorkflowData> getProcurementWorkflow({
    required RepositoryQuery query,
  }) =>
      _api.getProcurementWorkflow(query: query);

  @override
  Future<AssetLifecycleEvent> recordAssetLifecycleEvent({
    required RepositoryQuery query,
    required RecordAssetLifecycleEventRequest request,
  }) =>
      _api.recordAssetLifecycleEvent(query: query, request: request);

  @override
  Future<InventoryProcurementOrder> createProcurementOrder({
    required RepositoryQuery query,
    required CreateInventoryProcurementOrderRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.createProcurementOrder(query: query, request: request),
        mockCall: () => _mock.createProcurementOrder(query: query, request: request),
      );

  @override
  Future<InventoryProcurementOrder> approveProcurementOrder({
    required RepositoryQuery query,
    required String orderId,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.approveProcurementOrder(query: query, orderId: orderId),
        mockCall: () => _mock.approveProcurementOrder(query: query, orderId: orderId),
      );

  @override
  Future<InventoryProcurementOrder> recordProcurementReceiveHandoff({
    required RepositoryQuery query,
    required String orderId,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.recordProcurementReceiveHandoff(query: query, orderId: orderId),
        mockCall: () => _mock.recordProcurementReceiveHandoff(query: query, orderId: orderId),
      );
}

