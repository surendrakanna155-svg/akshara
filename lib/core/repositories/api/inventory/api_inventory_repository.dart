import '../../interfaces/inventory_repository.dart';
import '../../pagination_helpers.dart';
import '../../paginated_result.dart';
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
  Future<PaginatedResult<InventoryAsset>> getAssets({required RepositoryQuery query}) async {
    final dto = await _remote.fetchAssets(query: query);
    return paginateList(_mapper.toAssets(dto), query);
  }

  @override
  Future<PaginatedResult<InventoryCategory>> getCategories({required RepositoryQuery query}) async {
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
  Future<PaginatedResult<InventoryVendor>> getVendors({required RepositoryQuery query}) async {
    final dto = await _remote.fetchVendors(query: query);
    return paginateList(_mapper.toVendors(dto), query);
  }

  @override
  Future<InventoryReportsData> getReports({required RepositoryQuery query}) async {
    final dto = await _remote.fetchReports(query: query);
    return _mapper.toReports(dto);
  }
}
