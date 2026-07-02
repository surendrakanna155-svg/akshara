import '../../interfaces/hr_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/hr/hr_models.dart';
import '../../../../features/hr/hr_report_models.dart';
import '../../../../features/hr/hr_requests.dart';
import 'dto/hr_enum_codec.dart';
import 'mapper/hr_mapper.dart';
import 'remote/hr_remote_datasource.dart';

/// API implementation of [HrRepository] — enabled via [hrApiEnabledProvider].
class ApiHrRepository implements HrRepository {
  ApiHrRepository({
    required HrRemoteDataSource remote,
    HrMapper mapper = const HrMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final HrRemoteDataSource _remote;
  final HrMapper _mapper;

  @override
  Future<HrDashboardData> getDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<PaginatedResult<HrEmployee>> getEmployees({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchEmployees(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toEmployees(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<HrEmployeeDetail?> getEmployeeDetail({
    required RepositoryQuery query,
    required String employeeId,
  }) async {
    final dto = await _remote.fetchEmployeeDetail(
      query: query,
      employeeId: employeeId,
    );
    return _mapper.toEmployeeDetail(dto);
  }

  @override
  Future<HrAttendanceData> getAttendance({required RepositoryQuery query}) async {
    final dto = await _remote.fetchAttendance(query: query);
    return _mapper.toAttendance(dto);
  }

  @override
  Future<HrLeaveData> getLeave({required RepositoryQuery query}) async {
    final dto = await _remote.fetchLeave(query: query);
    return _mapper.toLeave(dto);
  }

  @override
  Future<HrPayrollData> getPayroll({required RepositoryQuery query}) async {
    final dto = await _remote.fetchPayroll(query: query);
    return _mapper.toPayroll(dto);
  }

  @override
  Future<HrRecruitmentData> getRecruitment({required RepositoryQuery query}) async {
    final dto = await _remote.fetchRecruitment(query: query);
    return _mapper.toRecruitment(dto);
  }

  @override
  Future<HrPerformanceData> getPerformance({required RepositoryQuery query}) async {
    final dto = await _remote.fetchPerformance(query: query);
    return _mapper.toPerformance(dto);
  }

  @override
  Future<HrSettingsData> getSettings({required RepositoryQuery query}) async {
    final dto = await _remote.fetchSettings(query: query);
    return _mapper.toSettings(dto);
  }

  @override
  Future<HrLeaveRequest> createLeaveRequest({
    required RepositoryQuery query,
    required CreateHrLeaveRequest request,
  }) async {
    final dto = await _remote.createLeaveRequest(
      query: query,
      data: {
        'employeeId': request.employeeId,
        'employeeName': request.employeeName,
        'department': HrEnumCodec.departmentToApi(request.department),
        'leaveType': HrEnumCodec.leaveTypeToApi(request.leaveType),
        'fromDate': request.fromDate,
        'toDate': request.toDate,
        'days': request.days,
        'reason': request.reason,
        'approver': request.approver,
      },
    );
    return _mapper.toLeaveRequest(dto);
  }

  @override
  Future<HrLeaveRequest> approveLeaveRequest({
    required RepositoryQuery query,
    required String leaveRequestId,
    required ApproveLeaveRequest request,
  }) async {
    final dto = await _remote.approveLeaveRequest(
      query: query,
      leaveRequestId: leaveRequestId,
      comment: request.comment,
    );
    return _mapper.toLeaveRequest(dto);
  }

  @override
  Future<HrLeaveRequest> rejectLeaveRequest({
    required RepositoryQuery query,
    required String leaveRequestId,
    required ApproveLeaveRequest request,
  }) async {
    final dto = await _remote.rejectLeaveRequest(
      query: query,
      leaveRequestId: leaveRequestId,
      comment: request.comment,
    );
    return _mapper.toLeaveRequest(dto);
  }

  @override
  Future<HrPayrollRun> processPayrollRun({
    required RepositoryQuery query,
    required ProcessHrPayrollRunRequest request,
  }) async {
    final dto = await _remote.processPayrollRun(
      query: query,
      data: {
        'runId': request.runId,
        if (request.processedOn != null) 'processedOn': request.processedOn,
      },
    );
    return _mapper.toPayrollRun(dto);
  }

  @override
  Future<HrEmployee> createEmployee({
    required RepositoryQuery query,
    required CreateHrEmployeeRequest request,
  }) async {
    final dto = await _remote.createEmployee(
      query: query,
      data: {
        'name': request.name,
        'employeeCode': request.employeeCode,
        'department': HrEnumCodec.departmentToApi(request.department),
        'role': HrEnumCodec.employeeRoleToApi(request.role),
        'designation': request.designation,
        'email': request.email,
        'phone': request.phone,
        'joinDate': request.joinDate,
      },
    );
    return _mapper.toEmployee(dto);
  }

  @override
  Future<HrEmployee> updateEmployee({
    required RepositoryQuery query,
    required UpdateHrEmployeeRequest request,
  }) async {
    final dto = await _remote.updateEmployee(
      query: query,
      employeeId: request.employeeId,
      data: {
        'name': request.name,
        'designation': request.designation,
        'phone': request.phone,
        'department': HrEnumCodec.departmentToApi(request.department),
      },
    );
    return _mapper.toEmployee(dto);
  }

  @override
  Future<HrEmployee> setEmployeeStatus({
    required RepositoryQuery query,
    required SetHrEmployeeStatusRequest request,
  }) async {
    final dto = await _remote.setEmployeeStatus(
      query: query,
      employeeId: request.employeeId,
      status: HrEnumCodec.employeeStatusToApi(request.status),
    );
    return _mapper.toEmployee(dto);
  }

  // --- HR reporting / export reads (HR-1/2/4/5/6/7) -------------------------

  @override
  Future<HrSalaryRegister> getSalaryRegister({
    required RepositoryQuery query,
    required String runId,
  }) async {
    final dto = await _remote.fetchSalaryRegister(query: query, runId: runId);
    return _mapper.toSalaryRegister(dto);
  }

  @override
  Future<HrPayslipBundle> getPayslips({
    required RepositoryQuery query,
    required String runId,
  }) async {
    final dto = await _remote.fetchPayslips(query: query, runId: runId);
    return _mapper.toPayslips(dto);
  }

  @override
  Future<HrAttendanceMuster> getAttendanceMuster({
    required RepositoryQuery query,
    required String month,
  }) async {
    final dto = await _remote.fetchAttendanceMuster(query: query, month: month);
    return _mapper.toAttendanceMuster(dto);
  }

  @override
  Future<HrLeaveBalanceReport> getLeaveBalances({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchLeaveBalances(query: query);
    return _mapper.toLeaveBalances(dto);
  }

  @override
  Future<HrHeadcountReport> getHeadcount({required RepositoryQuery query}) async {
    final dto = await _remote.fetchHeadcount(query: query);
    return _mapper.toHeadcount(dto);
  }

  @override
  Future<HrEmployeeDirectory> getEmployeeDirectory({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchEmployeeDirectory(query: query);
    return _mapper.toEmployeeDirectory(dto);
  }
}
