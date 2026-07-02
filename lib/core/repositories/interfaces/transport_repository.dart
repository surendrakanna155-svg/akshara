import '../../../features/transport/transport_models.dart';
import '../../../features/transport/transport_requests.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for transport data access (mock or API).
abstract class TransportRepository {
  Future<TransportDashboardData> getDashboard({required RepositoryQuery query});
  Future<PaginatedResult<TransportRoute>> getRoutes({required RepositoryQuery query});
  Future<PaginatedResult<TransportVehicle>> getVehicles({required RepositoryQuery query});
  Future<PaginatedResult<TransportDriver>> getDrivers({required RepositoryQuery query});
  Future<PaginatedResult<StudentTransportAllocation>> getAllocations({required RepositoryQuery query});
  Future<PaginatedResult<TransportAttendanceRecord>> getAttendanceRecords({required RepositoryQuery query});
  Future<TransportTrackingPlaceholderData> getTrackingPlaceholder({required RepositoryQuery query});
  Future<TransportReportsData> getReports({required RepositoryQuery query});
  Future<TransportSettingsData> getSettings({required RepositoryQuery query});
  Future<OccupancyMetrics> getOccupancyMetrics({required RepositoryQuery query});

  Future<TransportRoute> createRoute({
    required RepositoryQuery query,
    required CreateTransportRouteRequest request,
  });

  Future<TransportRoute> activateRoute({
    required RepositoryQuery query,
    required ActivateTransportRouteRequest request,
  });

  Future<TransportAttendanceRecord> recordAttendance({
    required RepositoryQuery query,
    required RecordTransportAttendanceRequest request,
  });

  Future<StudentTransportAllocation> assignStudentTransport({
    required RepositoryQuery query,
    required AssignStudentTransportRequest request,
  });

  Future<StudentTransportAllocation> transferStudentTransport({
    required RepositoryQuery query,
    required TransferStudentTransportRequest request,
  });

  Future<StudentTransportAllocation> removeStudentTransport({
    required RepositoryQuery query,
    required RemoveStudentTransportRequest request,
  });

  Future<TransportDelayNotificationResult> notifyRouteDelay({
    required RepositoryQuery query,
    required NotifyRouteDelayRequest request,
  });

  // ─── TRN-1/TRN-2: vehicle CRUD ──────────────────────────────────────────────

  Future<TransportVehicle> createVehicle({
    required RepositoryQuery query,
    required CreateTransportVehicleRequest request,
  });

  Future<TransportVehicle> updateVehicle({
    required RepositoryQuery query,
    required UpdateTransportVehicleRequest request,
  });

  Future<void> deleteVehicle({
    required RepositoryQuery query,
    required DeleteTransportVehicleRequest request,
  });

  // ─── TRN-1/TRN-2: driver CRUD ───────────────────────────────────────────────

  Future<TransportDriver> createDriver({
    required RepositoryQuery query,
    required CreateTransportDriverRequest request,
  });

  Future<TransportDriver> updateDriver({
    required RepositoryQuery query,
    required UpdateTransportDriverRequest request,
  });

  Future<void> deleteDriver({
    required RepositoryQuery query,
    required DeleteTransportDriverRequest request,
  });

  // ─── TRN-3: stop-wise roster ────────────────────────────────────────────────

  Future<RouteRoster> getRouteRoster({
    required RepositoryQuery query,
    required String routeId,
  });

  // ─── TRN-4: stop editor ─────────────────────────────────────────────────────

  Future<TransportRoute> addStop({
    required RepositoryQuery query,
    required AddTransportStopRequest request,
  });

  Future<TransportRoute> updateStop({
    required RepositoryQuery query,
    required UpdateTransportStopRequest request,
  });

  Future<TransportRoute> removeStop({
    required RepositoryQuery query,
    required RemoveTransportStopRequest request,
  });

  Future<TransportRoute> reorderStops({
    required RepositoryQuery query,
    required ReorderTransportStopsRequest request,
  });

  // ─── TRN-5: bulk allocation ─────────────────────────────────────────────────

  Future<BulkAllocationResult> bulkAllocateTransport({
    required RepositoryQuery query,
    required BulkAllocateTransportRequest request,
  });

  // ─── TRN-8: document-expiry reminder ────────────────────────────────────────

  Future<int> sendTransportDocumentExpiryReminder({
    required RepositoryQuery query,
    required SendTransportDocumentExpiryReminderRequest request,
  });

  // ─── TRN-9: raise a Finance transport-fee demand ────────────────────────────

  Future<TransportDemandResult> raiseTransportDemand({
    required RepositoryQuery query,
    required RaiseTransportDemandRequest request,
  });
}
