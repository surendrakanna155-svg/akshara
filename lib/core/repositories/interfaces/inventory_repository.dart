import '../../../features/inventory/inventory_models.dart';
import '../repository_query.dart';

/// Contract for inventory data access (mock or API).
abstract class InventoryRepository {
  Future<InventoryDashboardData> getDashboard({required RepositoryQuery query});
  Future<List<InventoryAsset>> getAssets({required RepositoryQuery query});
  Future<List<InventoryCategory>> getCategories({required RepositoryQuery query});
  Future<List<InventoryAllocation>> getAllocations({required RepositoryQuery query});
  Future<List<InventoryMaintenanceRecord>> getMaintenanceRecords({required RepositoryQuery query});
  Future<List<InventoryProcurementOrder>> getProcurementOrders({required RepositoryQuery query});
  Future<List<InventoryVendor>> getVendors({required RepositoryQuery query});
  Future<InventoryReportsData> getReports({required RepositoryQuery query});
}
