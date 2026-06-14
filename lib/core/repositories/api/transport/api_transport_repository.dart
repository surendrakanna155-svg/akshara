import '../../interfaces/transport_repository.dart';
import '../../pagination_helpers.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/transport/transport_models.dart';
import '../../../../features/transport/transport_requests.dart';
import '../api_exception.dart';
import 'mapper/transport_mapper.dart';
import 'remote/transport_remote_datasource.dart';

/// API implementation of [TransportRepository] — enabled via [transportApiEnabledProvider].
class ApiTransportRepository implements TransportRepository {
  ApiTransportRepository({
    required TransportRemoteDataSource remote,
    TransportMapper mapper = const TransportMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final TransportRemoteDataSource _remote;
  final TransportMapper _mapper;

  @override
  Future<TransportDashboardData> getDashboard({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<PaginatedResult<TransportRoute>> getRoutes({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchRoutes(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toRoutes(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<PaginatedResult<TransportVehicle>> getVehicles({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchVehicles(query: query);
    return paginateList(_mapper.toVehicles(dto), query);
  }

  @override
  Future<PaginatedResult<TransportDriver>> getDrivers({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchDrivers(query: query);
    return paginateList(_mapper.toDrivers(dto), query);
  }

  @override
  Future<PaginatedResult<StudentTransportAllocation>> getAllocations({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchAllocations(query: query);
    return paginateList(_mapper.toAllocations(dto), query);
  }

  @override
  Future<PaginatedResult<TransportAttendanceRecord>> getAttendanceRecords({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchAttendanceRecords(query: query);
    return paginateList(_mapper.toAttendanceRecords(dto), query);
  }

  @override
  Future<TransportTrackingPlaceholderData> getTrackingPlaceholder({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchTrackingPlaceholder(query: query);
    return _mapper.toTrackingPlaceholder(dto);
  }

  @override
  Future<TransportReportsData> getReports({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchReports(query: query);
    return _mapper.toReports(dto);
  }

  @override
  Future<TransportSettingsData> getSettings({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchSettings(query: query);
    return _mapper.toSettings(dto);
  }

  @override
  Future<OccupancyMetrics> getOccupancyMetrics({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchOccupancyMetrics(query: query);
    return _mapper.toOccupancyMetrics(dto);
  }

  @override
  Future<TransportRoute> createRoute({
    required RepositoryQuery query,
    required CreateTransportRouteRequest request,
  }) async {
    throw ApiNotConnectedException('TransportRepository', 'createRoute');
  }

  @override
  Future<TransportRoute> activateRoute({
    required RepositoryQuery query,
    required ActivateTransportRouteRequest request,
  }) async {
    throw ApiNotConnectedException('TransportRepository', 'activateRoute');
  }

  @override
  Future<StudentTransportAllocation> assignStudentTransport({
    required RepositoryQuery query,
    required AssignStudentTransportRequest request,
  }) async {
    throw ApiNotConnectedException('TransportRepository', 'assignStudentTransport');
  }

  @override
  Future<StudentTransportAllocation> transferStudentTransport({
    required RepositoryQuery query,
    required TransferStudentTransportRequest request,
  }) async {
    throw ApiNotConnectedException('TransportRepository', 'transferStudentTransport');
  }

  @override
  Future<StudentTransportAllocation> removeStudentTransport({
    required RepositoryQuery query,
    required RemoveStudentTransportRequest request,
  }) async {
    throw ApiNotConnectedException('TransportRepository', 'removeStudentTransport');
  }
}
