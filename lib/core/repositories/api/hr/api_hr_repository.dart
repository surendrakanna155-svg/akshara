import '../../interfaces/hr_repository.dart';
import '../../repository_query.dart';
import '../../../../features/hr/hr_models.dart';
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
  Future<List<HrEmployee>> getEmployees({required RepositoryQuery query}) async {
    final dto = await _remote.fetchEmployees(query: query);
    return _mapper.toEmployees(dto);
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
}
