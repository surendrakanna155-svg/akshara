// ignore_for_file: unused_field
import '../api_exception.dart';
import '../../repository_query.dart';
import '../../interfaces/inventory_repository.dart';
import '../../../../features/inventory/inventory_models.dart';
import 'mapper/inventory_mapper.dart';
import 'remote/inventory_remote_datasource.dart';

/// API implementation of [InventoryRepository] — swap via [useApiRepositoriesProvider].
class ApiInventoryRepository implements InventoryRepository {
  ApiInventoryRepository({
    required InventoryRemoteDataSource remote,
    InventoryMapper mapper = const InventoryMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final InventoryRemoteDataSource _remote;
  final InventoryMapper _mapper;

  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApiInventoryRepository', method);
  }

  @override
  Future<InventoryDashboardData> getDashboard({required RepositoryQuery query}) async => _notConnected('getDashboard');

  @override
  Future<List<InventoryAsset>> getAssets({required RepositoryQuery query}) async => _notConnected('getAssets');

  @override
  Future<List<InventoryCategory>> getCategories({required RepositoryQuery query}) async => _notConnected('getCategories');

  @override
  Future<List<InventoryAllocation>> getAllocations({required RepositoryQuery query}) async => _notConnected('getAllocations');

  @override
  Future<List<InventoryMaintenanceRecord>> getMaintenanceRecords({required RepositoryQuery query}) async => _notConnected('getMaintenanceRecords');

  @override
  Future<List<InventoryProcurementOrder>> getProcurementOrders({required RepositoryQuery query}) async => _notConnected('getProcurementOrders');

  @override
  Future<List<InventoryVendor>> getVendors({required RepositoryQuery query}) async => _notConnected('getVendors');

  @override
  Future<InventoryReportsData> getReports({required RepositoryQuery query}) async => _notConnected('getReports');
}
