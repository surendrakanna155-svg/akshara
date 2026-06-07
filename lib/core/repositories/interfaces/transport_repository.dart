import '../../../features/transport/transport_models.dart';
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
}
