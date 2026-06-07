import '../../../features/hr/hr_models.dart';
import '../repository_query.dart';

/// Contract for HR data access (mock or API).
abstract class HrRepository {
  Future<HrDashboardData> getDashboard({required RepositoryQuery query});
  Future<List<HrEmployee>> getEmployees({required RepositoryQuery query});
  Future<HrEmployeeDetail?> getEmployeeDetail({required RepositoryQuery query, required String employeeId});
  Future<HrAttendanceData> getAttendance({required RepositoryQuery query});
  Future<HrLeaveData> getLeave({required RepositoryQuery query});
  Future<HrPayrollData> getPayroll({required RepositoryQuery query});
  Future<HrRecruitmentData> getRecruitment({required RepositoryQuery query});
  Future<HrPerformanceData> getPerformance({required RepositoryQuery query});
  Future<HrSettingsData> getSettings({required RepositoryQuery query});
}
