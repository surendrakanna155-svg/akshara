import '../../../features/inventory/inventory_models.dart';
import '../../../features/inventory/inventory_requests.dart';
import '../../../features/inventory/intelligence/inventory_intelligence_models.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for inventory data access (mock or API).
abstract class InventoryRepository {
  Future<InventoryDashboardData> getDashboard({required RepositoryQuery query});
  Future<PaginatedResult<InventoryAsset>> getAssets({required RepositoryQuery query});
  Future<PaginatedResult<InventoryCategory>> getCategories({required RepositoryQuery query});
  Future<PaginatedResult<InventoryAllocation>> getAllocations({required RepositoryQuery query});
  Future<PaginatedResult<InventoryMaintenanceRecord>> getMaintenanceRecords({required RepositoryQuery query});
  Future<PaginatedResult<InventoryProcurementOrder>> getProcurementOrders({required RepositoryQuery query});
  Future<PaginatedResult<InventoryVendor>> getVendors({required RepositoryQuery query});
  Future<InventoryReportsData> getReports({required RepositoryQuery query});
  Future<InventoryCopilotData> getInventoryCopilot({required RepositoryQuery query});
  Future<AssetLifecycleData> getAssetLifecycle({required RepositoryQuery query});
  Future<ProcurementWorkflowData> getProcurementWorkflow({required RepositoryQuery query});
  Future<AssetLifecycleEvent> recordAssetLifecycleEvent({
    required RepositoryQuery query,
    required RecordAssetLifecycleEventRequest request,
  });

  Future<InventoryProcurementOrder> createProcurementOrder({
    required RepositoryQuery query,
    required CreateInventoryProcurementOrderRequest request,
  });

  Future<InventoryProcurementOrder> recordProcurementReceiveHandoff({
    required RepositoryQuery query,
    required String orderId,
  });
}
