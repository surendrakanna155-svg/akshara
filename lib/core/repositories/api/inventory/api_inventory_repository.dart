import '../../interfaces/inventory_repository.dart';
import '../../repository_query.dart';
import '../../../../features/inventory/inventory_models.dart';
import 'mapper/inventory_mapper.dart';
import 'remote/inventory_remote_datasource.dart';

/// API implementation of [InventoryRepository] — enabled via [inventoryApiEnabledProvider].
class ApiInventoryRepository implements InventoryRepository {
  ApiInventoryRepository({
    required InventoryRemoteDataSource remote,
    InventoryMapper mapper = const InventoryMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final InventoryRemoteDataSource _remote;
  final InventoryMapper _mapper;

  @override
  Future<InventoryDashboardData> getDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<List<InventoryAsset>> getAssets({required RepositoryQuery query}) async {
    final dto = await _remote.fetchAssets(query: query);
    return _mapper.toAssets(dto);
  }

  @override
  Future<List<InventoryCategory>> getCategories({required RepositoryQuery query}) async {
    final dto = await _remote.fetchCategories(query: query);
    return _mapper.toCategories(dto);
  }

  @override
  Future<List<InventoryAllocation>> getAllocations({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchAllocations(query: query);
    return _mapper.toAllocations(dto);
  }

  @override
  Future<List<InventoryMaintenanceRecord>> getMaintenanceRecords({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchMaintenanceRecords(query: query);
    return _mapper.toMaintenanceRecords(dto);
  }

  @override
  Future<List<InventoryProcurementOrder>> getProcurementOrders({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchProcurementOrders(query: query);
    return _mapper.toProcurementOrders(dto);
  }

  @override
  Future<List<InventoryVendor>> getVendors({required RepositoryQuery query}) async {
    final dto = await _remote.fetchVendors(query: query);
    return _mapper.toVendors(dto);
  }

  @override
  Future<InventoryReportsData> getReports({required RepositoryQuery query}) async {
    final dto = await _remote.fetchReports(query: query);
    return _mapper.toReports(dto);
  }
}
