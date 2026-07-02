import '../../interfaces/transport_repository.dart';
import '../../mock/mock_transport_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/transport/transport_models.dart';
import '../../../../features/transport/transport_requests.dart';
import 'api_transport_repository.dart';
import '../hybrid_write_fallback.dart';

class HybridTransportRepository implements TransportRepository {
  HybridTransportRepository({
    required ApiTransportRepository api,
    required MockTransportRepository mock,
  })  : _api = api,
        _mock = mock;

  final ApiTransportRepository _api;
  final MockTransportRepository _mock;

  @override
  Future<TransportDashboardData> getDashboard({required RepositoryQuery query}) =>
      _api.getDashboard(query: query);

  @override
  Future<PaginatedResult<TransportRoute>> getRoutes({required RepositoryQuery query}) =>
      _api.getRoutes(query: query);

  @override
  Future<PaginatedResult<TransportVehicle>> getVehicles({required RepositoryQuery query}) =>
      _api.getVehicles(query: query);

  @override
  Future<PaginatedResult<TransportDriver>> getDrivers({required RepositoryQuery query}) =>
      _api.getDrivers(query: query);

  @override
  Future<PaginatedResult<StudentTransportAllocation>> getAllocations({
    required RepositoryQuery query,
  }) =>
      _api.getAllocations(query: query);

  @override
  Future<PaginatedResult<TransportAttendanceRecord>> getAttendanceRecords({
    required RepositoryQuery query,
  }) =>
      _api.getAttendanceRecords(query: query);

  @override
  Future<TransportTrackingPlaceholderData> getTrackingPlaceholder({
    required RepositoryQuery query,
  }) =>
      _api.getTrackingPlaceholder(query: query);

  @override
  Future<TransportReportsData> getReports({required RepositoryQuery query}) =>
      _api.getReports(query: query);

  @override
  Future<TransportSettingsData> getSettings({required RepositoryQuery query}) =>
      _api.getSettings(query: query);

  @override
  Future<OccupancyMetrics> getOccupancyMetrics({required RepositoryQuery query}) =>
      _api.getOccupancyMetrics(query: query);

  @override
  Future<TransportRoute> createRoute({
    required RepositoryQuery query,
    required CreateTransportRouteRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.createRoute(query: query, request: request),
        mockCall: () => _mock.createRoute(query: query, request: request),
      );

  @override
  Future<TransportRoute> activateRoute({
    required RepositoryQuery query,
    required ActivateTransportRouteRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.activateRoute(query: query, request: request),
        mockCall: () => _mock.activateRoute(query: query, request: request),
      );

  @override
  Future<TransportAttendanceRecord> recordAttendance({
    required RepositoryQuery query,
    required RecordTransportAttendanceRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.recordAttendance(query: query, request: request),
        mockCall: () => _mock.recordAttendance(query: query, request: request),
      );

  @override
  Future<StudentTransportAllocation> assignStudentTransport({
    required RepositoryQuery query,
    required AssignStudentTransportRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.assignStudentTransport(query: query, request: request),
        mockCall: () => _mock.assignStudentTransport(query: query, request: request),
      );

  @override
  Future<StudentTransportAllocation> transferStudentTransport({
    required RepositoryQuery query,
    required TransferStudentTransportRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.transferStudentTransport(query: query, request: request),
        mockCall: () => _mock.transferStudentTransport(query: query, request: request),
      );

  @override
  Future<StudentTransportAllocation> removeStudentTransport({
    required RepositoryQuery query,
    required RemoveStudentTransportRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.removeStudentTransport(query: query, request: request),
        mockCall: () => _mock.removeStudentTransport(query: query, request: request),
      );

  @override
  Future<TransportDelayNotificationResult> notifyRouteDelay({
    required RepositoryQuery query,
    required NotifyRouteDelayRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.notifyRouteDelay(query: query, request: request),
        mockCall: () => _mock.notifyRouteDelay(query: query, request: request),
      );

  @override
  Future<TransportVehicle> createVehicle({
    required RepositoryQuery query,
    required CreateTransportVehicleRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.createVehicle(query: query, request: request),
        mockCall: () => _mock.createVehicle(query: query, request: request),
      );

  @override
  Future<TransportVehicle> updateVehicle({
    required RepositoryQuery query,
    required UpdateTransportVehicleRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.updateVehicle(query: query, request: request),
        mockCall: () => _mock.updateVehicle(query: query, request: request),
      );

  @override
  Future<void> deleteVehicle({
    required RepositoryQuery query,
    required DeleteTransportVehicleRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.deleteVehicle(query: query, request: request),
        mockCall: () => _mock.deleteVehicle(query: query, request: request),
      );

  @override
  Future<TransportDriver> createDriver({
    required RepositoryQuery query,
    required CreateTransportDriverRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.createDriver(query: query, request: request),
        mockCall: () => _mock.createDriver(query: query, request: request),
      );

  @override
  Future<TransportDriver> updateDriver({
    required RepositoryQuery query,
    required UpdateTransportDriverRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.updateDriver(query: query, request: request),
        mockCall: () => _mock.updateDriver(query: query, request: request),
      );

  @override
  Future<void> deleteDriver({
    required RepositoryQuery query,
    required DeleteTransportDriverRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.deleteDriver(query: query, request: request),
        mockCall: () => _mock.deleteDriver(query: query, request: request),
      );

  @override
  Future<RouteRoster> getRouteRoster({
    required RepositoryQuery query,
    required String routeId,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getRouteRoster(query: query, routeId: routeId),
        mockCall: () => _mock.getRouteRoster(query: query, routeId: routeId),
      );

  @override
  Future<TransportRoute> addStop({
    required RepositoryQuery query,
    required AddTransportStopRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.addStop(query: query, request: request),
        mockCall: () => _mock.addStop(query: query, request: request),
      );

  @override
  Future<TransportRoute> updateStop({
    required RepositoryQuery query,
    required UpdateTransportStopRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.updateStop(query: query, request: request),
        mockCall: () => _mock.updateStop(query: query, request: request),
      );

  @override
  Future<TransportRoute> removeStop({
    required RepositoryQuery query,
    required RemoveTransportStopRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.removeStop(query: query, request: request),
        mockCall: () => _mock.removeStop(query: query, request: request),
      );

  @override
  Future<TransportRoute> reorderStops({
    required RepositoryQuery query,
    required ReorderTransportStopsRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.reorderStops(query: query, request: request),
        mockCall: () => _mock.reorderStops(query: query, request: request),
      );

  @override
  Future<BulkAllocationResult> bulkAllocateTransport({
    required RepositoryQuery query,
    required BulkAllocateTransportRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () =>
            _api.bulkAllocateTransport(query: query, request: request),
        mockCall: () =>
            _mock.bulkAllocateTransport(query: query, request: request),
      );

  @override
  Future<int> sendTransportDocumentExpiryReminder({
    required RepositoryQuery query,
    required SendTransportDocumentExpiryReminderRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.sendTransportDocumentExpiryReminder(
          query: query,
          request: request,
        ),
        mockCall: () => _mock.sendTransportDocumentExpiryReminder(
          query: query,
          request: request,
        ),
      );

  @override
  Future<TransportDemandResult> raiseTransportDemand({
    required RepositoryQuery query,
    required RaiseTransportDemandRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () =>
            _api.raiseTransportDemand(query: query, request: request),
        mockCall: () =>
            _mock.raiseTransportDemand(query: query, request: request),
      );
}
