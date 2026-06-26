import '../../interfaces/hostel_repository.dart';
import '../../mock/mock_hostel_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/hostel/hostel_models.dart';
import '../../../../features/hostel/hostel_requests.dart';
import 'api_hostel_repository.dart';
import '../hybrid_write_fallback.dart';

/// API reads with mock fallback for hostel writes.
class HybridHostelRepository implements HostelRepository {
  HybridHostelRepository({
    required ApiHostelRepository api,
    required MockHostelRepository mock,
  })  : _api = api,
        _mock = mock;

  final ApiHostelRepository _api;
  final MockHostelRepository _mock;

  @override
  Future<HostelDashboardData> getDashboard({required RepositoryQuery query}) =>
      _api.getDashboard(query: query);

  @override
  Future<PaginatedResult<HostelStudent>> getStudents({
    required RepositoryQuery query,
  }) =>
      _api.getStudents(query: query);

  @override
  Future<PaginatedResult<HostelRoom>> getRooms({
    required RepositoryQuery query,
  }) =>
      _api.getRooms(query: query);

  @override
  Future<PaginatedResult<HostelAttendanceRecord>> getAttendanceRecords({
    required RepositoryQuery query,
  }) =>
      _api.getAttendanceRecords(query: query);

  @override
  Future<PaginatedResult<HostelLeaveRequest>> getLeaveRequests({
    required RepositoryQuery query,
  }) =>
      _api.getLeaveRequests(query: query);

  @override
  Future<HostelMessData> getMessData({required RepositoryQuery query}) =>
      _api.getMessData(query: query);

  @override
  Future<HostelVisitorsData> getVisitors({required RepositoryQuery query}) =>
      _api.getVisitors(query: query);

  @override
  Future<HostelReportsData> getReports({required RepositoryQuery query}) =>
      _api.getReports(query: query);

  @override
  Future<HostelOccupancyMetrics> getOccupancyMetrics({
    required RepositoryQuery query,
  }) =>
      _api.getOccupancyMetrics(query: query);

  @override
  Future<HostelStudent> admitHostelStudent({
    required RepositoryQuery query,
    required AdmitHostelStudentRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.admitHostelStudent(query: query, request: request),
        mockCall: () => _mock.admitHostelStudent(query: query, request: request),
      );

  @override
  Future<HostelStudent> assignHostelRoom({
    required RepositoryQuery query,
    required AssignHostelRoomRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.assignHostelRoom(query: query, request: request),
        mockCall: () => _mock.assignHostelRoom(query: query, request: request),
      );

  @override
  Future<HostelStudent> checkoutHostelStudent({
    required RepositoryQuery query,
    required CheckoutHostelStudentRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.checkoutHostelStudent(query: query, request: request),
        mockCall: () =>
            _mock.checkoutHostelStudent(query: query, request: request),
      );

  @override
  Future<HostelRoom> createHostelRoom({
    required RepositoryQuery query,
    required CreateHostelRoomRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.createHostelRoom(query: query, request: request),
        mockCall: () => _mock.createHostelRoom(query: query, request: request),
      );

  @override
  Future<HostelVisitor> logVisitor({
    required RepositoryQuery query,
    required LogVisitorRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.logVisitor(query: query, request: request),
        mockCall: () => _mock.logVisitor(query: query, request: request),
      );

  @override
  Future<HostelAttendanceRecord> recordHostelAttendance({
    required RepositoryQuery query,
    required RecordHostelAttendanceRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () =>
            _api.recordHostelAttendance(query: query, request: request),
        mockCall: () =>
            _mock.recordHostelAttendance(query: query, request: request),
      );

  @override
  Future<HostelMealMenu> recordMess({
    required RepositoryQuery query,
    required RecordMessRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.recordMess(query: query, request: request),
        mockCall: () => _mock.recordMess(query: query, request: request),
      );
}

