import '../../interfaces/transport_repository.dart';
import '../../pagination_helpers.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/transport/transport_models.dart';
import '../../../../features/transport/transport_requests.dart';
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
    final dto = await _remote.createRoute(query: query, request: request);
    return _mapper.toRoute(dto);
  }

  @override
  Future<TransportRoute> activateRoute({
    required RepositoryQuery query,
    required ActivateTransportRouteRequest request,
  }) async {
    final dto = await _remote.activateRoute(query: query, request: request);
    return _mapper.toRoute(dto);
  }

  @override
  Future<TransportAttendanceRecord> recordAttendance({
    required RepositoryQuery query,
    required RecordTransportAttendanceRequest request,
  }) async {
    final dto = await _remote.recordAttendance(query: query, request: request);
    return _mapper.toAttendanceRecord(dto);
  }

  @override
  Future<StudentTransportAllocation> assignStudentTransport({
    required RepositoryQuery query,
    required AssignStudentTransportRequest request,
  }) async {
    final dto = await _remote.assignStudentTransport(query: query, request: request);
    return _mapper.toAllocation(dto);
  }

  @override
  Future<StudentTransportAllocation> transferStudentTransport({
    required RepositoryQuery query,
    required TransferStudentTransportRequest request,
  }) async {
    final dto = await _remote.transferStudentTransport(query: query, request: request);
    return _mapper.toAllocation(dto);
  }

  @override
  Future<StudentTransportAllocation> removeStudentTransport({
    required RepositoryQuery query,
    required RemoveStudentTransportRequest request,
  }) async {
    final dto = await _remote.removeStudentTransport(query: query, request: request);
    return _mapper.toAllocation(dto);
  }

  @override
  Future<TransportDelayNotificationResult> notifyRouteDelay({
    required RepositoryQuery query,
    required NotifyRouteDelayRequest request,
  }) async {
    final dto = await _remote.notifyRouteDelay(query: query, request: request);
    return _mapper.toDelayNotification(dto);
  }

  @override
  Future<TransportVehicle> createVehicle({
    required RepositoryQuery query,
    required CreateTransportVehicleRequest request,
  }) async {
    final dto = await _remote.createVehicle(query: query, request: request);
    return _mapper.toVehicle(dto);
  }

  @override
  Future<TransportVehicle> updateVehicle({
    required RepositoryQuery query,
    required UpdateTransportVehicleRequest request,
  }) async {
    final dto = await _remote.updateVehicle(query: query, request: request);
    return _mapper.toVehicle(dto);
  }

  @override
  Future<void> deleteVehicle({
    required RepositoryQuery query,
    required DeleteTransportVehicleRequest request,
  }) async {
    await _remote.deleteVehicle(query: query, request: request);
  }

  @override
  Future<TransportDriver> createDriver({
    required RepositoryQuery query,
    required CreateTransportDriverRequest request,
  }) async {
    final dto = await _remote.createDriver(query: query, request: request);
    return _mapper.toDriver(dto);
  }

  @override
  Future<TransportDriver> updateDriver({
    required RepositoryQuery query,
    required UpdateTransportDriverRequest request,
  }) async {
    final dto = await _remote.updateDriver(query: query, request: request);
    return _mapper.toDriver(dto);
  }

  @override
  Future<void> deleteDriver({
    required RepositoryQuery query,
    required DeleteTransportDriverRequest request,
  }) async {
    await _remote.deleteDriver(query: query, request: request);
  }

  @override
  Future<RouteRoster> getRouteRoster({
    required RepositoryQuery query,
    required String routeId,
  }) async {
    final dto = await _remote.fetchRouteRoster(query: query, routeId: routeId);
    return _mapper.toRoster(dto);
  }

  @override
  Future<TransportRoute> addStop({
    required RepositoryQuery query,
    required AddTransportStopRequest request,
  }) async {
    final dto = await _remote.addStop(query: query, request: request);
    return _mapper.toRoute(dto);
  }

  @override
  Future<TransportRoute> updateStop({
    required RepositoryQuery query,
    required UpdateTransportStopRequest request,
  }) async {
    final dto = await _remote.updateStop(query: query, request: request);
    return _mapper.toRoute(dto);
  }

  @override
  Future<TransportRoute> removeStop({
    required RepositoryQuery query,
    required RemoveTransportStopRequest request,
  }) async {
    final dto = await _remote.removeStop(query: query, request: request);
    return _mapper.toRoute(dto);
  }

  @override
  Future<TransportRoute> reorderStops({
    required RepositoryQuery query,
    required ReorderTransportStopsRequest request,
  }) async {
    final dto = await _remote.reorderStops(query: query, request: request);
    return _mapper.toRoute(dto);
  }

  @override
  Future<BulkAllocationResult> bulkAllocateTransport({
    required RepositoryQuery query,
    required BulkAllocateTransportRequest request,
  }) async {
    final dto =
        await _remote.bulkAllocateTransport(query: query, request: request);
    return _mapper.toBulkAllocationResult(dto);
  }

  @override
  Future<int> sendTransportDocumentExpiryReminder({
    required RepositoryQuery query,
    required SendTransportDocumentExpiryReminderRequest request,
  }) async {
    final dto = await _remote.sendDocumentExpiryReminder(
      query: query,
      request: request,
    );
    return _mapper.toDocumentExpiryReminderCount(dto);
  }

  @override
  Future<TransportDemandResult> raiseTransportDemand({
    required RepositoryQuery query,
    required RaiseTransportDemandRequest request,
  }) async {
    final dto =
        await _remote.raiseTransportDemand(query: query, request: request);
    return _mapper.toDemandResult(dto);
  }
}
