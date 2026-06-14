import '../../../features/hr/hr_models.dart';
import '../../../features/hr/hr_requests.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for HR data access (mock or API).
abstract class HrRepository {
  Future<HrDashboardData> getDashboard({required RepositoryQuery query});
  Future<PaginatedResult<HrEmployee>> getEmployees({required RepositoryQuery query});
  Future<HrEmployeeDetail?> getEmployeeDetail({required RepositoryQuery query, required String employeeId});
  Future<HrAttendanceData> getAttendance({required RepositoryQuery query});
  Future<HrLeaveData> getLeave({required RepositoryQuery query});
  Future<HrPayrollData> getPayroll({required RepositoryQuery query});
  Future<HrRecruitmentData> getRecruitment({required RepositoryQuery query});
  Future<HrPerformanceData> getPerformance({required RepositoryQuery query});
  Future<HrSettingsData> getSettings({required RepositoryQuery query});

  Future<HrLeaveRequest> createLeaveRequest({
    required RepositoryQuery query,
    required CreateHrLeaveRequest request,
  });

  Future<HrPayrollRun> processPayrollRun({
    required RepositoryQuery query,
    required ProcessHrPayrollRunRequest request,
  });

  Future<HrEmployee> createEmployee({
    required RepositoryQuery query,
    required CreateHrEmployeeRequest request,
  });

  Future<HrEmployee> updateEmployee({
    required RepositoryQuery query,
    required UpdateHrEmployeeRequest request,
  });

  Future<HrEmployee> setEmployeeStatus({
    required RepositoryQuery query,
    required SetHrEmployeeStatusRequest request,
  });
}
