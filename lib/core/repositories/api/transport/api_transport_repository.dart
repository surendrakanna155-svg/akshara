// ignore_for_file: unused_field
import '../api_exception.dart';
import '../../repository_query.dart';
import '../../interfaces/transport_repository.dart';
import 'mapper/transport_mapper.dart';
import '../../../../features/transport/transport_models.dart';
import 'remote/transport_remote_datasource.dart';

/// API implementation of [TransportRepository] — swap via [useApiRepositoriesProvider].
class ApiTransportRepository implements TransportRepository {
  ApiTransportRepository({
    required TransportRemoteDataSource remote,
    TransportMapper mapper = const TransportMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final TransportRemoteDataSource _remote;
  final TransportMapper _mapper;

  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApiTransportRepository', method);
  }

  @override
  Future<TransportDashboardData> getDashboard({required RepositoryQuery query}) async => _notConnected('getDashboard');

  @override
  Future<List<TransportRoute>> getRoutes({required RepositoryQuery query}) async => _notConnected('getRoutes');

  @override
  Future<List<TransportVehicle>> getVehicles({required RepositoryQuery query}) async => _notConnected('getVehicles');

  @override
  Future<List<TransportDriver>> getDrivers({required RepositoryQuery query}) async => _notConnected('getDrivers');

  @override
  Future<List<StudentTransportAllocation>> getAllocations({required RepositoryQuery query}) async => _notConnected('getAllocations');

  @override
  Future<List<TransportAttendanceRecord>> getAttendanceRecords({required RepositoryQuery query}) async => _notConnected('getAttendanceRecords');

  @override
  Future<TransportTrackingPlaceholderData> getTrackingPlaceholder({required RepositoryQuery query}) async => _notConnected('getTrackingPlaceholder');

  @override
  Future<TransportReportsData> getReports({required RepositoryQuery query}) async => _notConnected('getReports');

  @override
  Future<TransportSettingsData> getSettings({required RepositoryQuery query}) async => _notConnected('getSettings');

  @override
  Future<OccupancyMetrics> getOccupancyMetrics({required RepositoryQuery query}) async => _notConnected('getOccupancyMetrics');

}