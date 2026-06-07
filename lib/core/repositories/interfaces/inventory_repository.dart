import '../../../features/inventory/inventory_models.dart';
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
}
