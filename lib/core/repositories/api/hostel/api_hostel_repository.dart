import '../../interfaces/hostel_repository.dart';
import '../../pagination_helpers.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/hostel/hostel_models.dart';
import '../../../../features/hostel/hostel_requests.dart';
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
  Future<PaginatedResult<HostelStudent>> getStudents({required RepositoryQuery query}) async {
    final dto = await _remote.fetchStudents(query: query);
    return paginateList(_mapper.toStudents(dto), query);
  }

  @override
  Future<PaginatedResult<HostelRoom>> getRooms({required RepositoryQuery query}) async {
    final dto = await _remote.fetchRooms(query: query);
    return paginateList(_mapper.toRooms(dto), query);
  }

  @override
  Future<PaginatedResult<HostelAttendanceRecord>> getAttendanceRecords({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchAttendanceRecords(query: query);
    return paginateList(_mapper.toAttendanceRecords(dto), query);
  }

  @override
  Future<PaginatedResult<HostelLeaveRequest>> getLeaveRequests({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchLeaveRequests(query: query);
    return paginateList(_mapper.toLeaveRequests(dto), query);
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

  @override
  Future<HostelStudent> admitHostelStudent({
    required RepositoryQuery query,
    required AdmitHostelStudentRequest request,
  }) async {
    final dto = await _remote.admitStudent(query: query, request: request);
    return _mapper.toStudent(dto);
  }

  @override
  Future<HostelStudent> assignHostelRoom({
    required RepositoryQuery query,
    required AssignHostelRoomRequest request,
  }) async {
    final dto = await _remote.assignRoom(query: query, request: request);
    return _mapper.toStudent(dto);
  }

  @override
  Future<HostelStudent> checkoutHostelStudent({
    required RepositoryQuery query,
    required CheckoutHostelStudentRequest request,
  }) async {
    final dto = await _remote.checkoutStudent(query: query, request: request);
    return _mapper.toStudent(dto);
  }

  @override
  Future<HostelRoom> createHostelRoom({
    required RepositoryQuery query,
    required CreateHostelRoomRequest request,
  }) async {
    final dto = await _remote.createRoom(query: query, request: request);
    return _mapper.toRoom(dto);
  }

  @override
  Future<HostelVisitor> logVisitor({
    required RepositoryQuery query,
    required LogVisitorRequest request,
  }) async {
    final dto = await _remote.logVisitor(query: query, request: request);
    return _mapper.toVisitor(dto);
  }

  @override
  Future<HostelAttendanceRecord> recordHostelAttendance({
    required RepositoryQuery query,
    required RecordHostelAttendanceRequest request,
  }) async {
    final dto = await _remote.recordAttendance(query: query, request: request);
    return _mapper.toAttendanceRecord(dto);
  }

  @override
  Future<HostelMealMenu> recordMess({
    required RepositoryQuery query,
    required RecordMessRequest request,
  }) async {
    final dto = await _remote.recordMess(query: query, request: request);
    return _mapper.toMealMenu(dto);
  }
}
