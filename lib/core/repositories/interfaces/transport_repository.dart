import '../../../features/transport/transport_models.dart';
import '../repository_query.dart';

/// Contract for transport data access (mock or API).
abstract class TransportRepository {
  Future<TransportDashboardData> getDashboard({required RepositoryQuery query});
  Future<List<TransportRoute>> getRoutes({required RepositoryQuery query});
  Future<List<TransportVehicle>> getVehicles({required RepositoryQuery query});
  Future<List<TransportDriver>> getDrivers({required RepositoryQuery query});
  Future<List<StudentTransportAllocation>> getAllocations({required RepositoryQuery query});
  Future<List<TransportAttendanceRecord>> getAttendanceRecords({required RepositoryQuery query});
  Future<TransportTrackingPlaceholderData> getTrackingPlaceholder({required RepositoryQuery query});
  Future<TransportReportsData> getReports({required RepositoryQuery query});
  Future<TransportSettingsData> getSettings({required RepositoryQuery query});
  Future<OccupancyMetrics> getOccupancyMetrics({required RepositoryQuery query});
}
