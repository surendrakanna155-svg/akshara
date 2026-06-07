import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tenant/tenant_provider.dart';
import '../../core/providers/repository_future.dart';

import '../../core/repositories/paginated_result.dart';
import '../../core/repositories/repository_providers.dart';
import 'hostel_models.dart';

// HO-01 Dashboard
final hostelDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final hostelDashboardErrorProvider = StateProvider<bool>((ref) => false);
final hostelDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final hostelDashboardFilterProvider = StateProvider<int>((ref) => 0);

final hostelDashboardFutureProvider = FutureProvider<HostelDashboardData>((ref) async {
return await ref.read(hostelRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

final hostelDashboardProvider = Provider<HostelDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hostelDashboardFutureProvider),
    manualLoading: ref.watch(hostelDashboardLoadingProvider), manualError: ref.watch(hostelDashboardErrorProvider), manualEmpty: ref.watch(hostelDashboardEmptyProvider),
  );
});

// HO-02 Students
final hostelStudentsLoadingProvider = StateProvider<bool>((ref) => false);
final hostelStudentsErrorProvider = StateProvider<bool>((ref) => false);
final hostelStudentsEmptyProvider = StateProvider<bool>((ref) => false);
final hostelStudentsFilterProvider = StateProvider<int>((ref) => 0);

final hostelStudentsFutureProvider = FutureProvider<PaginatedResult<HostelStudent>>((ref) async {
return ref.read(hostelRepositoryProvider).getStudents(query: ref.watch(repositoryQueryProvider));
});

final hostelStudentsProvider = Provider<List<HostelStudent>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hostelStudentsFutureProvider),
    manualLoading: ref.watch(hostelStudentsLoadingProvider), manualError: ref.watch(hostelStudentsErrorProvider), manualEmpty: ref.watch(hostelStudentsEmptyProvider),
  )?.items ?? const [];
});

final hostelFilteredStudentsProvider = Provider<List<HostelStudent>>((ref) {
  final students = ref.watch(hostelStudentsProvider);
  if (students == null) return const [];
  final filterIndex = ref.watch(hostelStudentsFilterProvider);
  return switch (filterIndex) {
    1 => students
        .where((s) => s.status == HostelStudentStatus.resident)
        .toList(),
    2 => students
        .where((s) => s.status == HostelStudentStatus.onLeave)
        .toList(),
    3 => students
        .where((s) => s.status == HostelStudentStatus.checkedOut)
        .toList(),
    _ => students,
  };
});

// HO-03 Rooms
final hostelRoomsLoadingProvider = StateProvider<bool>((ref) => false);
final hostelRoomsErrorProvider = StateProvider<bool>((ref) => false);
final hostelRoomsEmptyProvider = StateProvider<bool>((ref) => false);
final hostelRoomsFilterProvider = StateProvider<int>((ref) => 0);

final hostelRoomsFutureProvider = FutureProvider<PaginatedResult<HostelRoom>>((ref) async {
return ref.read(hostelRepositoryProvider).getRooms(query: ref.watch(repositoryQueryProvider));
});

final hostelRoomsProvider = Provider<List<HostelRoom>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hostelRoomsFutureProvider),
    manualLoading: ref.watch(hostelRoomsLoadingProvider), manualError: ref.watch(hostelRoomsErrorProvider), manualEmpty: ref.watch(hostelRoomsEmptyProvider),
  )?.items ?? const [];
});

final hostelFilteredRoomsProvider = Provider<List<HostelRoom>>((ref) {
  final rooms = ref.watch(hostelRoomsProvider);
  if (rooms == null) return const [];
  final filterIndex = ref.watch(hostelRoomsFilterProvider);
  return switch (filterIndex) {
    1 => rooms
        .where((r) => r.status == HostelRoomStatus.occupied)
        .toList(),
    2 => rooms
        .where((r) => r.status == HostelRoomStatus.vacant)
        .toList(),
    3 => rooms
        .where((r) => r.status == HostelRoomStatus.maintenance)
        .toList(),
    _ => rooms,
  };
});

// HO-04 Attendance
final hostelAttendanceLoadingProvider = StateProvider<bool>((ref) => false);
final hostelAttendanceErrorProvider = StateProvider<bool>((ref) => false);
final hostelAttendanceEmptyProvider = StateProvider<bool>((ref) => false);
final hostelAttendanceFilterProvider = StateProvider<int>((ref) => 0);

final hostelAttendanceFutureProvider =
    FutureProvider<PaginatedResult<HostelAttendanceRecord>>((ref) async {
  return ref.read(hostelRepositoryProvider).getAttendanceRecords(
        query: ref.watch(repositoryQueryProvider),
      );
});

final hostelAttendanceProvider =
    Provider<List<HostelAttendanceRecord>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hostelAttendanceFutureProvider),
    manualLoading: ref.watch(hostelAttendanceLoadingProvider),
    manualError: ref.watch(hostelAttendanceErrorProvider),
    manualEmpty: ref.watch(hostelAttendanceEmptyProvider),
  )?.items;
});

final hostelFilteredAttendanceProvider =
    Provider<List<HostelAttendanceRecord>>((ref) {
  final records = ref.watch(hostelAttendanceProvider);
  if (records == null) return const [];
  final filterIndex = ref.watch(hostelAttendanceFilterProvider);
  return switch (filterIndex) {
    1 => records
        .where((r) => r.overallStatus == HostelAttendanceStatus.present)
        .toList(),
    2 => records
        .where((r) => r.overallStatus == HostelAttendanceStatus.absent)
        .toList(),
    3 => records
        .where((r) => r.overallStatus == HostelAttendanceStatus.onLeave)
        .toList(),
    _ => records,
  };
});

// HO-05 Leave
final hostelLeaveLoadingProvider = StateProvider<bool>((ref) => false);
final hostelLeaveErrorProvider = StateProvider<bool>((ref) => false);
final hostelLeaveEmptyProvider = StateProvider<bool>((ref) => false);
final hostelLeaveFilterProvider = StateProvider<int>((ref) => 0);

final hostelLeaveFutureProvider = FutureProvider<PaginatedResult<HostelLeaveRequest>>((ref) async {
return ref.read(hostelRepositoryProvider).getLeaveRequests(query: ref.watch(repositoryQueryProvider));
});

final hostelLeaveProvider = Provider<List<HostelLeaveRequest>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hostelLeaveFutureProvider),
    manualLoading: ref.watch(hostelLeaveLoadingProvider), manualError: ref.watch(hostelLeaveErrorProvider), manualEmpty: ref.watch(hostelLeaveEmptyProvider),
  )?.items ?? const [];
});

final hostelFilteredLeaveProvider = Provider<List<HostelLeaveRequest>>((ref) {
  final requests = ref.watch(hostelLeaveProvider);
  if (requests == null) return const [];
  final filterIndex = ref.watch(hostelLeaveFilterProvider);
  return switch (filterIndex) {
    1 => requests
        .where((r) => r.status == HostelLeaveStatus.pending)
        .toList(),
    2 => requests
        .where((r) => r.status == HostelLeaveStatus.approved)
        .toList(),
    3 => requests
        .where((r) => r.status == HostelLeaveStatus.rejected)
        .toList(),
    4 => requests
        .where((r) => r.status == HostelLeaveStatus.active)
        .toList(),
    _ => requests,
  };
});

// HO-06 Mess
final hostelMessLoadingProvider = StateProvider<bool>((ref) => false);
final hostelMessErrorProvider = StateProvider<bool>((ref) => false);
final hostelMessEmptyProvider = StateProvider<bool>((ref) => false);

final hostelMessFutureProvider = FutureProvider<HostelMessData>((ref) async {
return await ref.read(hostelRepositoryProvider).getMessData(query: ref.watch(repositoryQueryProvider));
});

final hostelMessProvider = Provider<HostelMessData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hostelMessFutureProvider),
    manualLoading: ref.watch(hostelMessLoadingProvider), manualError: ref.watch(hostelMessErrorProvider), manualEmpty: ref.watch(hostelMessEmptyProvider),
  );
});

// HO-07 Visitors
final hostelVisitorsLoadingProvider = StateProvider<bool>((ref) => false);
final hostelVisitorsErrorProvider = StateProvider<bool>((ref) => false);
final hostelVisitorsEmptyProvider = StateProvider<bool>((ref) => false);

final hostelVisitorsFutureProvider = FutureProvider<HostelVisitorsData>((ref) async {
return await ref.read(hostelRepositoryProvider).getVisitors(query: ref.watch(repositoryQueryProvider));
});

final hostelVisitorsProvider = Provider<HostelVisitorsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hostelVisitorsFutureProvider),
    manualLoading: ref.watch(hostelVisitorsLoadingProvider), manualError: ref.watch(hostelVisitorsErrorProvider), manualEmpty: ref.watch(hostelVisitorsEmptyProvider),
  );
});

// HO-08 Reports
final hostelReportsLoadingProvider = StateProvider<bool>((ref) => false);
final hostelReportsErrorProvider = StateProvider<bool>((ref) => false);
final hostelReportsEmptyProvider = StateProvider<bool>((ref) => false);

final hostelReportsFutureProvider = FutureProvider<HostelReportsData>((ref) async {
return await ref.read(hostelRepositoryProvider).getReports(query: ref.watch(repositoryQueryProvider));
});

final hostelReportsProvider = Provider<HostelReportsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(hostelReportsFutureProvider),
    manualLoading: ref.watch(hostelReportsLoadingProvider), manualError: ref.watch(hostelReportsErrorProvider), manualEmpty: ref.watch(hostelReportsEmptyProvider),
  );
});
