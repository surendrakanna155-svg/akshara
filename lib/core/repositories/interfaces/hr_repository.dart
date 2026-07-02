import '../../../features/hr/hr_models.dart';
import '../../../features/hr/hr_report_models.dart';
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

  Future<HrLeaveRequest> approveLeaveRequest({
    required RepositoryQuery query,
    required String leaveRequestId,
    required ApproveLeaveRequest request,
  });

  Future<HrLeaveRequest> rejectLeaveRequest({
    required RepositoryQuery query,
    required String leaveRequestId,
    required ApproveLeaveRequest request,
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

  // --- HR reporting / export reads (HR-1/2/4/5/6/7) -------------------------

  /// HR-1 — salary register for one payroll run (rows + column totals).
  Future<HrSalaryRegister> getSalaryRegister({
    required RepositoryQuery query,
    required String runId,
  });

  /// HR-2 — per-employee payslip data for one payroll run.
  Future<HrPayslipBundle> getPayslips({
    required RepositoryQuery query,
    required String runId,
  });

  /// HR-6 — monthly attendance muster (employee × day, inferred from check-ins).
  Future<HrAttendanceMuster> getAttendanceMuster({
    required RepositoryQuery query,
    required String month, // YYYY-MM
  });

  /// HR-4 — per employee × leave-type balance report.
  Future<HrLeaveBalanceReport> getLeaveBalances({required RepositoryQuery query});

  /// HR-5 — active headcount grouped by department.
  Future<HrHeadcountReport> getHeadcount({required RepositoryQuery query});

  /// HR-7 — employee directory rows.
  Future<HrEmployeeDirectory> getEmployeeDirectory({required RepositoryQuery query});
}
