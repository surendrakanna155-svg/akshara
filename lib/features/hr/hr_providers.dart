import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tenant/tenant_provider.dart';
import '../../core/providers/repository_future.dart';
import '../../core/repositories/paginated_result.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/repositories/repository_providers.dart';
import 'hr_models.dart';

// HR-01 Dashboard
final hrDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final hrDashboardErrorProvider = StateProvider<bool>((ref) => false);
final hrDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final hrDashboardFilterProvider = StateProvider<int>((ref) => 0);

final hrDashboardFutureProvider = FutureProvider<HrDashboardData>((ref) async {
return await ref.read(hrRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

final hrDashboardProvider = Provider<HrDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hrDashboardFutureProvider),
    manualLoading: ref.watch(hrDashboardLoadingProvider), manualError: ref.watch(hrDashboardErrorProvider), manualEmpty: ref.watch(hrDashboardEmptyProvider),
  );
});

// HR-02 Employees
final hrEmployeesLoadingProvider = StateProvider<bool>((ref) => false);
final hrEmployeesErrorProvider = StateProvider<bool>((ref) => false);
final hrEmployeesEmptyProvider = StateProvider<bool>((ref) => false);
final hrEmployeesFilterProvider = StateProvider<int>((ref) => 0);
final hrEmployeesPageProvider = StateProvider<int>((ref) => 1);

final hrEmployeesQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(hrEmployeesPageProvider);
  return baseQuery.withPage(page);
});

final hrEmployeesFutureProvider =
    FutureProvider<PaginatedResult<HrEmployee>>((ref) async {
  return ref.read(hrRepositoryProvider).getEmployees(
        query: ref.watch(hrEmployeesQueryProvider),
      );
});

final hrEmployeesPageResultProvider =
    Provider<PaginatedResult<HrEmployee>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hrEmployeesFutureProvider),
    manualLoading: ref.watch(hrEmployeesLoadingProvider),
    manualError: ref.watch(hrEmployeesErrorProvider),
    manualEmpty: ref.watch(hrEmployeesEmptyProvider),
  );
});

final hrEmployeesProvider = Provider<List<HrEmployee>>((ref) {
  return ref.watch(hrEmployeesPageResultProvider)?.items ?? const [];
});

final hrFilteredEmployeesProvider = Provider<List<HrEmployee>>((ref) {
  final employees = ref.watch(hrEmployeesProvider);
  final filterIndex = ref.watch(hrEmployeesFilterProvider);
  return switch (filterIndex) {
    1 => employees
        .where((e) => e.status == HrEmployeeStatus.active)
        .toList(),
    2 => employees
        .where((e) => e.status == HrEmployeeStatus.onLeave)
        .toList(),
    3 => employees
        .where((e) => e.role == HrEmployeeRole.teacher)
        .toList(),
    _ => employees,
  };
});

// HR-03 Employee Profile
final hrEmployeeProfileLoadingProvider = StateProvider<bool>((ref) => false);
final hrEmployeeProfileErrorProvider = StateProvider<bool>((ref) => false);

final hrEmployeeDetailFutureProvider =
    FutureProvider.family<HrEmployeeDetail?, String>((ref, employeeId) async {
  return ref.read(hrRepositoryProvider).getEmployeeDetail(
        query: ref.watch(repositoryQueryProvider),
        employeeId: employeeId,
      );
});

final hrEmployeeDetailProvider =
    Provider.family<HrEmployeeDetail?, String>((ref, employeeId) {
  if (ref.watch(hrEmployeeProfileLoadingProvider)) return null;
  if (ref.watch(hrEmployeeProfileErrorProvider)) return null;
  return watchRepositoryFuture<HrEmployeeDetail?>(
    ref,
    ref.watch(hrEmployeeDetailFutureProvider(employeeId)),
    manualLoading: false,
    manualError: false,
    manualEmpty: false,
  );
});

// HR-04 Attendance
final hrAttendanceLoadingProvider = StateProvider<bool>((ref) => false);
final hrAttendanceErrorProvider = StateProvider<bool>((ref) => false);
final hrAttendanceEmptyProvider = StateProvider<bool>((ref) => false);
final hrAttendanceFilterProvider = StateProvider<int>((ref) => 0);

final hrAttendanceFutureProvider = FutureProvider<HrAttendanceData>((ref) async {
return await ref.read(hrRepositoryProvider).getAttendance(query: ref.watch(repositoryQueryProvider));
});

final hrAttendanceProvider = Provider<HrAttendanceData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hrAttendanceFutureProvider),
    manualLoading: ref.watch(hrAttendanceLoadingProvider), manualError: ref.watch(hrAttendanceErrorProvider), manualEmpty: ref.watch(hrAttendanceEmptyProvider),
  );
});

final hrFilteredAttendanceProvider = Provider<List<HrAttendanceRecord>>((ref) {
  final data = ref.watch(hrAttendanceProvider);
  if (data == null) return const [];
  final filterIndex = ref.watch(hrAttendanceFilterProvider);
  return switch (filterIndex) {
    1 => data.records
        .where((r) => r.status == HrAttendanceStatus.present)
        .toList(),
    2 => data.records
        .where((r) => r.status == HrAttendanceStatus.late)
        .toList(),
    3 => data.records
        .where((r) => r.status == HrAttendanceStatus.onLeave)
        .toList(),
    _ => data.records,
  };
});

// HR-05 Leave
final hrLeaveLoadingProvider = StateProvider<bool>((ref) => false);
final hrLeaveErrorProvider = StateProvider<bool>((ref) => false);
final hrLeaveEmptyProvider = StateProvider<bool>((ref) => false);
final hrLeaveFilterProvider = StateProvider<int>((ref) => 0);

final hrLeaveFutureProvider = FutureProvider<HrLeaveData>((ref) async {
return await ref.read(hrRepositoryProvider).getLeave(query: ref.watch(repositoryQueryProvider));
});

final hrLeaveProvider = Provider<HrLeaveData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hrLeaveFutureProvider),
    manualLoading: ref.watch(hrLeaveLoadingProvider), manualError: ref.watch(hrLeaveErrorProvider), manualEmpty: ref.watch(hrLeaveEmptyProvider),
  );
});

final hrFilteredLeaveProvider = Provider<List<HrLeaveRequest>>((ref) {
  final data = ref.watch(hrLeaveProvider);
  if (data == null) return const [];
  final filterIndex = ref.watch(hrLeaveFilterProvider);
  return switch (filterIndex) {
    1 => data.requests
        .where((r) => r.status == HrLeaveStatus.pending)
        .toList(),
    2 => data.requests
        .where((r) => r.status == HrLeaveStatus.approved)
        .toList(),
    3 => data.requests
        .where((r) => r.status == HrLeaveStatus.rejected)
        .toList(),
    _ => data.requests,
  };
});

// HR-06 Payroll
final hrPayrollLoadingProvider = StateProvider<bool>((ref) => false);
final hrPayrollErrorProvider = StateProvider<bool>((ref) => false);
final hrPayrollEmptyProvider = StateProvider<bool>((ref) => false);
final hrPayrollFilterProvider = StateProvider<int>((ref) => 0);

final hrPayrollFutureProvider = FutureProvider<HrPayrollData>((ref) async {
return await ref.read(hrRepositoryProvider).getPayroll(query: ref.watch(repositoryQueryProvider));
});

final hrPayrollProvider = Provider<HrPayrollData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hrPayrollFutureProvider),
    manualLoading: ref.watch(hrPayrollLoadingProvider), manualError: ref.watch(hrPayrollErrorProvider), manualEmpty: ref.watch(hrPayrollEmptyProvider),
  );
});

// HR-07 Recruitment
final hrRecruitmentLoadingProvider = StateProvider<bool>((ref) => false);
final hrRecruitmentErrorProvider = StateProvider<bool>((ref) => false);
final hrRecruitmentEmptyProvider = StateProvider<bool>((ref) => false);
final hrRecruitmentFilterProvider = StateProvider<int>((ref) => 0);

final hrRecruitmentFutureProvider = FutureProvider<HrRecruitmentData>((ref) async {
return await ref.read(hrRepositoryProvider).getRecruitment(query: ref.watch(repositoryQueryProvider));
});

final hrRecruitmentProvider = Provider<HrRecruitmentData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hrRecruitmentFutureProvider),
    manualLoading: ref.watch(hrRecruitmentLoadingProvider), manualError: ref.watch(hrRecruitmentErrorProvider), manualEmpty: ref.watch(hrRecruitmentEmptyProvider),
  );
});

final hrFilteredCandidatesProvider = Provider<List<HrCandidate>>((ref) {
  final data = ref.watch(hrRecruitmentProvider);
  if (data == null) return const [];
  final filterIndex = ref.watch(hrRecruitmentFilterProvider);
  return switch (filterIndex) {
    1 => data.candidates
        .where((c) => c.stage == HrRecruitmentStage.applied)
        .toList(),
    2 => data.candidates
        .where((c) => c.stage == HrRecruitmentStage.interview)
        .toList(),
    3 => data.candidates
        .where((c) => c.stage == HrRecruitmentStage.joined)
        .toList(),
    _ => data.candidates,
  };
});

// HR-08 Performance
final hrPerformanceLoadingProvider = StateProvider<bool>((ref) => false);
final hrPerformanceErrorProvider = StateProvider<bool>((ref) => false);
final hrPerformanceEmptyProvider = StateProvider<bool>((ref) => false);
final hrPerformanceFilterProvider = StateProvider<int>((ref) => 0);

final hrPerformanceFutureProvider = FutureProvider<HrPerformanceData>((ref) async {
return await ref.read(hrRepositoryProvider).getPerformance(query: ref.watch(repositoryQueryProvider));
});

final hrPerformanceProvider = Provider<HrPerformanceData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hrPerformanceFutureProvider),
    manualLoading: ref.watch(hrPerformanceLoadingProvider), manualError: ref.watch(hrPerformanceErrorProvider), manualEmpty: ref.watch(hrPerformanceEmptyProvider),
  );
});

final hrFilteredReviewsProvider = Provider<List<HrPerformanceReview>>((ref) {
  final data = ref.watch(hrPerformanceProvider);
  if (data == null) return const [];
  final filterIndex = ref.watch(hrPerformanceFilterProvider);
  return switch (filterIndex) {
    1 => data.reviews
        .where((r) => r.status == HrReviewStatus.inProgress)
        .toList(),
    2 => data.reviews
        .where((r) => r.status == HrReviewStatus.completed)
        .toList(),
    3 => data.reviews
        .where((r) => r.status == HrReviewStatus.overdue)
        .toList(),
    _ => data.reviews,
  };
});

// HR-09 Settings
final hrSettingsLoadingProvider = StateProvider<bool>((ref) => false);
final hrSettingsErrorProvider = StateProvider<bool>((ref) => false);

final hrSettingsFutureProvider = FutureProvider<HrSettingsData>((ref) async {
return await ref.read(hrRepositoryProvider).getSettings(query: ref.watch(repositoryQueryProvider));
});

final hrSettingsProvider = Provider<HrSettingsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hrSettingsFutureProvider),
    manualLoading: ref.watch(hrSettingsLoadingProvider), manualError: ref.watch(hrSettingsErrorProvider), manualEmpty: false,
  );
});
