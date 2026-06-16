import '../../interfaces/hr_repository.dart';
import '../../mock/mock_hr_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/hr/hr_models.dart';
import '../../../../features/hr/hr_requests.dart';
import 'api_hr_repository.dart';
import '../hybrid_write_fallback.dart';

/// API reads with mock write fallback for pilot operations.
class HybridHrRepository implements HrRepository {
  HybridHrRepository({
    required ApiHrRepository api,
    required MockHrRepository mock,
  })  : _api = api,
        _mock = mock;

  final ApiHrRepository _api;
  final MockHrRepository _mock;

  @override
  Future<HrDashboardData> getDashboard({required RepositoryQuery query}) =>
      _api.getDashboard(query: query);

  @override
  Future<PaginatedResult<HrEmployee>> getEmployees({
    required RepositoryQuery query,
  }) =>
      _api.getEmployees(query: query);

  @override
  Future<HrEmployeeDetail?> getEmployeeDetail({
    required RepositoryQuery query,
    required String employeeId,
  }) =>
      _api.getEmployeeDetail(query: query, employeeId: employeeId);

  @override
  Future<HrAttendanceData> getAttendance({required RepositoryQuery query}) =>
      _api.getAttendance(query: query);

  @override
  Future<HrLeaveData> getLeave({required RepositoryQuery query}) =>
      _api.getLeave(query: query);

  @override
  Future<HrPayrollData> getPayroll({required RepositoryQuery query}) =>
      _api.getPayroll(query: query);

  @override
  Future<HrRecruitmentData> getRecruitment({required RepositoryQuery query}) =>
      _api.getRecruitment(query: query);

  @override
  Future<HrPerformanceData> getPerformance({required RepositoryQuery query}) =>
      _api.getPerformance(query: query);

  @override
  Future<HrSettingsData> getSettings({required RepositoryQuery query}) =>
      _api.getSettings(query: query);

  @override
  Future<HrLeaveRequest> createLeaveRequest({
    required RepositoryQuery query,
    required CreateHrLeaveRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.createLeaveRequest(query: query, request: request),
        mockCall: () => _mock.createLeaveRequest(query: query, request: request),
      );

  @override
  Future<HrLeaveRequest> approveLeaveRequest({
    required RepositoryQuery query,
    required String leaveRequestId,
    required ApproveLeaveRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.approveLeaveRequest(
          query: query,
          leaveRequestId: leaveRequestId,
          request: request,
        ),
        mockCall: () => _mock.approveLeaveRequest(
          query: query,
          leaveRequestId: leaveRequestId,
          request: request,
        ),
      );

  @override
  Future<HrLeaveRequest> rejectLeaveRequest({
    required RepositoryQuery query,
    required String leaveRequestId,
    required ApproveLeaveRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.rejectLeaveRequest(
          query: query,
          leaveRequestId: leaveRequestId,
          request: request,
        ),
        mockCall: () => _mock.rejectLeaveRequest(
          query: query,
          leaveRequestId: leaveRequestId,
          request: request,
        ),
      );

  @override
  Future<HrPayrollRun> processPayrollRun({
    required RepositoryQuery query,
    required ProcessHrPayrollRunRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.processPayrollRun(query: query, request: request),
        mockCall: () => _mock.processPayrollRun(query: query, request: request),
      );

  @override
  Future<HrEmployee> createEmployee({
    required RepositoryQuery query,
    required CreateHrEmployeeRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.createEmployee(query: query, request: request),
        mockCall: () => _mock.createEmployee(query: query, request: request),
      );

  @override
  Future<HrEmployee> updateEmployee({
    required RepositoryQuery query,
    required UpdateHrEmployeeRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.updateEmployee(query: query, request: request),
        mockCall: () => _mock.updateEmployee(query: query, request: request),
      );

  @override
  Future<HrEmployee> setEmployeeStatus({
    required RepositoryQuery query,
    required SetHrEmployeeStatusRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.setEmployeeStatus(query: query, request: request),
        mockCall: () => _mock.setEmployeeStatus(query: query, request: request),
      );
}
