// ignore_for_file: unused_field
import '../api_exception.dart';
import '../../repository_query.dart';
import '../../interfaces/hr_repository.dart';
import '../../../../features/hr/hr_models.dart';
import 'mapper/hr_mapper.dart';
import 'remote/hr_remote_datasource.dart';

/// API implementation of [HrRepository] — swap via [useApiRepositoriesProvider].
class ApiHrRepository implements HrRepository {
  ApiHrRepository({
    required HrRemoteDataSource remote,
    HrMapper mapper = const HrMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final HrRemoteDataSource _remote;
  final HrMapper _mapper;

  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApiHrRepository', method);
  }

  @override
  Future<HrDashboardData> getDashboard({required RepositoryQuery query}) async => _notConnected('getDashboard');

  @override
  Future<List<HrEmployee>> getEmployees({required RepositoryQuery query}) async => _notConnected('getEmployees');

  @override
  Future<HrEmployeeDetail?> getEmployeeDetail({required RepositoryQuery query, required String employeeId}) async => _notConnected('getEmployeeDetail');

  @override
  Future<HrAttendanceData> getAttendance({required RepositoryQuery query}) async => _notConnected('getAttendance');

  @override
  Future<HrLeaveData> getLeave({required RepositoryQuery query}) async => _notConnected('getLeave');

  @override
  Future<HrPayrollData> getPayroll({required RepositoryQuery query}) async => _notConnected('getPayroll');

  @override
  Future<HrRecruitmentData> getRecruitment({required RepositoryQuery query}) async => _notConnected('getRecruitment');

  @override
  Future<HrPerformanceData> getPerformance({required RepositoryQuery query}) async => _notConnected('getPerformance');

  @override
  Future<HrSettingsData> getSettings({required RepositoryQuery query}) async => _notConnected('getSettings');
}
