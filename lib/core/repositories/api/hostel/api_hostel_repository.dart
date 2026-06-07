// ignore_for_file: unused_field
import '../../../../features/hostel/hostel_models.dart';
import '../api_exception.dart';
import '../../repository_query.dart';
import '../../interfaces/hostel_repository.dart';
import 'mapper/hostel_mapper.dart';
import 'remote/hostel_remote_datasource.dart';

/// API implementation of [HostelRepository] — swap via [useApiRepositoriesProvider].
class ApiHostelRepository implements HostelRepository {
  ApiHostelRepository({
    required HostelRemoteDataSource remote,
    HostelMapper mapper = const HostelMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final HostelRemoteDataSource _remote;
  final HostelMapper _mapper;

  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApiHostelRepository', method);
  }

  @override
  Future<HostelDashboardData> getDashboard({required RepositoryQuery query}) async => _notConnected('getDashboard');

  @override
  Future<List<HostelStudent>> getStudents({required RepositoryQuery query}) async => _notConnected('getStudents');

  @override
  Future<List<HostelRoom>> getRooms({required RepositoryQuery query}) async => _notConnected('getRooms');

  @override
  Future<List<HostelAttendanceRecord>> getAttendanceRecords({required RepositoryQuery query}) async => _notConnected('getAttendanceRecords');

  @override
  Future<List<HostelLeaveRequest>> getLeaveRequests({required RepositoryQuery query}) async => _notConnected('getLeaveRequests');

  @override
  Future<HostelMessData> getMessData({required RepositoryQuery query}) async => _notConnected('getMessData');

  @override
  Future<HostelVisitorsData> getVisitors({required RepositoryQuery query}) async => _notConnected('getVisitors');

  @override
  Future<HostelReportsData> getReports({required RepositoryQuery query}) async => _notConnected('getReports');

  @override
  Future<HostelOccupancyMetrics> getOccupancyMetrics({required RepositoryQuery query}) async => _notConnected('getOccupancyMetrics');
}
