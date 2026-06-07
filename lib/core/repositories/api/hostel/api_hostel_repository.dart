import '../../interfaces/hostel_repository.dart';
import '../../repository_query.dart';
import '../../../../features/hostel/hostel_models.dart';
import 'mapper/hostel_mapper.dart';
import 'remote/hostel_remote_datasource.dart';

/// API implementation of [HostelRepository] — enabled via [hostelApiEnabledProvider].
class ApiHostelRepository implements HostelRepository {
  ApiHostelRepository({
    required HostelRemoteDataSource remote,
    HostelMapper mapper = const HostelMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final HostelRemoteDataSource _remote;
  final HostelMapper _mapper;

  @override
  Future<HostelDashboardData> getDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<List<HostelStudent>> getStudents({required RepositoryQuery query}) async {
    final dto = await _remote.fetchStudents(query: query);
    return _mapper.toStudents(dto);
  }

  @override
  Future<List<HostelRoom>> getRooms({required RepositoryQuery query}) async {
    final dto = await _remote.fetchRooms(query: query);
    return _mapper.toRooms(dto);
  }

  @override
  Future<List<HostelAttendanceRecord>> getAttendanceRecords({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchAttendanceRecords(query: query);
    return _mapper.toAttendanceRecords(dto);
  }

  @override
  Future<List<HostelLeaveRequest>> getLeaveRequests({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchLeaveRequests(query: query);
    return _mapper.toLeaveRequests(dto);
  }

  @override
  Future<HostelMessData> getMessData({required RepositoryQuery query}) async {
    final dto = await _remote.fetchMessData(query: query);
    return _mapper.toMessData(dto);
  }

  @override
  Future<HostelVisitorsData> getVisitors({required RepositoryQuery query}) async {
    final dto = await _remote.fetchVisitors(query: query);
    return _mapper.toVisitors(dto);
  }

  @override
  Future<HostelReportsData> getReports({required RepositoryQuery query}) async {
    final dto = await _remote.fetchReports(query: query);
    return _mapper.toReports(dto);
  }

  @override
  Future<HostelOccupancyMetrics> getOccupancyMetrics({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchOccupancyMetrics(query: query);
    return _mapper.toOccupancyMetrics(dto);
  }
}
