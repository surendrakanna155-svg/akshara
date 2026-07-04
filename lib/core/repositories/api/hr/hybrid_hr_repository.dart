import '../../interfaces/hr_repository.dart';
import '../../mock/mock_hr_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/hr/hr_models.dart';
import '../../../../features/hr/hr_report_models.dart';
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
  Future<HrBatchLeaveDecision> batchDecideLeave({
    required RepositoryQuery query,
    required BatchDecideHrLeaveRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.batchDecideLeave(query: query, request: request),
        mockCall: () => _mock.batchDecideLeave(query: query, request: request),
      );

  @override
  Future<HrSalaryStructure> upsertSalaryStructure({
    required RepositoryQuery query,
    required UpsertHrSalaryStructureRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.upsertSalaryStructure(query: query, request: request),
        mockCall: () => _mock.upsertSalaryStructure(query: query, request: request),
      );

  @override
  Future<HrPayrollRun> generatePayrollRun({
    required RepositoryQuery query,
    required GenerateHrPayrollRunRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.generatePayrollRun(query: query, request: request),
        mockCall: () => _mock.generatePayrollRun(query: query, request: request),
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

  @override
  Future<HrEmployee> setEmployeeProbation({
    required RepositoryQuery query,
    required SetHrEmployeeProbationRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.setEmployeeProbation(query: query, request: request),
        mockCall: () => _mock.setEmployeeProbation(query: query, request: request),
      );

  // --- HR reporting / export reads (HR-1/2/4/5/6/7). Reads go to the API. ----

  @override
  Future<HrSalaryRegister> getSalaryRegister({
    required RepositoryQuery query,
    required String runId,
  }) =>
      _api.getSalaryRegister(query: query, runId: runId);

  @override
  Future<HrPayslipBundle> getPayslips({
    required RepositoryQuery query,
    required String runId,
  }) =>
      _api.getPayslips(query: query, runId: runId);

  @override
  Future<HrAttendanceMuster> getAttendanceMuster({
    required RepositoryQuery query,
    required String month,
  }) =>
      _api.getAttendanceMuster(query: query, month: month);

  @override
  Future<HrLeaveBalanceReport> getLeaveBalances({required RepositoryQuery query}) =>
      _api.getLeaveBalances(query: query);

  @override
  Future<HrHeadcountReport> getHeadcount({required RepositoryQuery query}) =>
      _api.getHeadcount(query: query);

  @override
  Future<HrEmployeeDirectory> getEmployeeDirectory({required RepositoryQuery query}) =>
      _api.getEmployeeDirectory(query: query);

  @override
  Future<HrExpiringDocumentsReport> getExpiringDocuments({
    required RepositoryQuery query,
    int withinDays = 30,
  }) =>
      _api.getExpiringDocuments(query: query, withinDays: withinDays);

  @override
  Future<HrProbationEndingReport> getProbationEnding({
    required RepositoryQuery query,
    int withinDays = 15,
  }) =>
      _api.getProbationEnding(query: query, withinDays: withinDays);
}
