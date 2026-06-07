import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tenant/tenant_provider.dart';
import '../../core/providers/repository_future.dart';

import '../../core/repositories/repository_providers.dart';
import 'management_models.dart';

// MG-01 Dashboard
final managementDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final managementDashboardErrorProvider = StateProvider<bool>((ref) => false);
final managementDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final managementDashboardFilterProvider = StateProvider<int>((ref) => 0);

final managementDashboardFutureProvider = FutureProvider<ManagementDashboardData>((ref) async {
return await ref.read(managementRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

final managementDashboardProvider = Provider<ManagementDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(managementDashboardFutureProvider),
    manualLoading: ref.watch(managementDashboardLoadingProvider), manualError: ref.watch(managementDashboardErrorProvider), manualEmpty: ref.watch(managementDashboardEmptyProvider),
  );
});

// MG-02 Analytics
final managementAnalyticsLoadingProvider = StateProvider<bool>((ref) => false);
final managementAnalyticsErrorProvider = StateProvider<bool>((ref) => false);
final managementAnalyticsEmptyProvider = StateProvider<bool>((ref) => false);
final managementAnalyticsFilterProvider = StateProvider<int>((ref) => 0);

final managementAnalyticsFutureProvider = FutureProvider<ManagementAnalyticsData>((ref) async {
return await ref.read(managementRepositoryProvider).getAnalytics(query: ref.watch(repositoryQueryProvider));
});

final managementAnalyticsProvider = Provider<ManagementAnalyticsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(managementAnalyticsFutureProvider),
    manualLoading: ref.watch(managementAnalyticsLoadingProvider), manualError: ref.watch(managementAnalyticsErrorProvider), manualEmpty: ref.watch(managementAnalyticsEmptyProvider),
  );
});

// MG-03 Admissions Funnel
final managementAdmissionsLoadingProvider = StateProvider<bool>((ref) => false);
final managementAdmissionsErrorProvider = StateProvider<bool>((ref) => false);
final managementAdmissionsEmptyProvider = StateProvider<bool>((ref) => false);
final managementAdmissionsFilterProvider = StateProvider<int>((ref) => 0);

final managementAdmissionsFunnelFutureProvider =
    FutureProvider<ManagementAdmissionsFunnelData>((ref) async {
  return ref.read(managementRepositoryProvider).getAdmissionsFunnel(
        query: ref.watch(repositoryQueryProvider),
      );
});

final managementAdmissionsFunnelProvider =
    Provider<ManagementAdmissionsFunnelData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(managementAdmissionsFunnelFutureProvider),
    manualLoading: ref.watch(managementAdmissionsLoadingProvider),
    manualError: ref.watch(managementAdmissionsErrorProvider),
    manualEmpty: ref.watch(managementAdmissionsEmptyProvider),
  );
});

// MG-04 Financial Health
final managementFinanceLoadingProvider = StateProvider<bool>((ref) => false);
final managementFinanceErrorProvider = StateProvider<bool>((ref) => false);
final managementFinanceEmptyProvider = StateProvider<bool>((ref) => false);
final managementFinanceFilterProvider = StateProvider<int>((ref) => 0);

final managementFinancialHealthFutureProvider =
    FutureProvider<ManagementFinancialHealthData>((ref) async {
  return ref.read(managementRepositoryProvider).getFinancialHealth(
        query: ref.watch(repositoryQueryProvider),
      );
});

final managementFinancialHealthProvider =
    Provider<ManagementFinancialHealthData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(managementFinancialHealthFutureProvider),
    manualLoading: ref.watch(managementFinanceLoadingProvider),
    manualError: ref.watch(managementFinanceErrorProvider),
    manualEmpty: ref.watch(managementFinanceEmptyProvider),
  );
});

// MG-05 Academic Health
final managementAcademicsLoadingProvider = StateProvider<bool>((ref) => false);
final managementAcademicsErrorProvider = StateProvider<bool>((ref) => false);
final managementAcademicsEmptyProvider = StateProvider<bool>((ref) => false);
final managementAcademicsFilterProvider = StateProvider<int>((ref) => 0);

final managementAcademicHealthFutureProvider =
    FutureProvider<ManagementAcademicHealthData>((ref) async {
  return ref.read(managementRepositoryProvider).getAcademicHealth(
        query: ref.watch(repositoryQueryProvider),
      );
});

final managementAcademicHealthProvider =
    Provider<ManagementAcademicHealthData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(managementAcademicHealthFutureProvider),
    manualLoading: ref.watch(managementAcademicsLoadingProvider),
    manualError: ref.watch(managementAcademicsErrorProvider),
    manualEmpty: ref.watch(managementAcademicsEmptyProvider),
  );
});

// MG-06 School Performance
final managementPerformanceLoadingProvider = StateProvider<bool>((ref) => false);
final managementPerformanceErrorProvider = StateProvider<bool>((ref) => false);
final managementPerformanceEmptyProvider = StateProvider<bool>((ref) => false);
final managementPerformanceFilterProvider = StateProvider<int>((ref) => 0);

final managementSchoolPerformanceFutureProvider =
    FutureProvider<ManagementPerformanceData>((ref) async {
  return ref.read(managementRepositoryProvider).getSchoolPerformance(
        query: ref.watch(repositoryQueryProvider),
      );
});

final managementSchoolPerformanceProvider =
    Provider<ManagementPerformanceData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(managementSchoolPerformanceFutureProvider),
    manualLoading: ref.watch(managementPerformanceLoadingProvider),
    manualError: ref.watch(managementPerformanceErrorProvider),
    manualEmpty: ref.watch(managementPerformanceEmptyProvider),
  );
});

// MG-07 Tasks & Approvals
final managementTasksLoadingProvider = StateProvider<bool>((ref) => false);
final managementTasksErrorProvider = StateProvider<bool>((ref) => false);
final managementTasksEmptyProvider = StateProvider<bool>((ref) => false);
final managementTasksFilterProvider = StateProvider<int>((ref) => 0);
final managementSelectedApprovalIdProvider = StateProvider<String?>((ref) => null);

final managementTasksFutureProvider = FutureProvider<ManagementTasksData>((ref) async {
return await ref.read(managementRepositoryProvider).getTasksAndApprovals(query: ref.watch(repositoryQueryProvider));
});

final managementTasksProvider = Provider<ManagementTasksData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(managementTasksFutureProvider),
    manualLoading: ref.watch(managementTasksLoadingProvider), manualError: ref.watch(managementTasksErrorProvider), manualEmpty: ref.watch(managementTasksEmptyProvider),
  );
});

final managementFilteredApprovalsProvider =
    Provider<List<ManagementApprovalItem>>((ref) {
  final data = ref.watch(managementTasksProvider);
  if (data == null) return const [];
  final filterIndex = ref.watch(managementTasksFilterProvider);
  return switch (filterIndex) {
    1 => data.approvals
        .where((a) => a.status == ManagementApprovalStatus.pending)
        .toList(),
    2 => data.approvals
        .where((a) => a.status == ManagementApprovalStatus.approved)
        .toList(),
    3 => data.approvals
        .where((a) => a.status == ManagementApprovalStatus.rejected)
        .toList(),
    _ => data.approvals,
  };
});

// MG-08 Settings
final managementSettingsLoadingProvider = StateProvider<bool>((ref) => false);
final managementSettingsErrorProvider = StateProvider<bool>((ref) => false);

final managementSettingsFutureProvider = FutureProvider<ManagementSettingsData>((ref) async {
return await ref.read(managementRepositoryProvider).getSettings(query: ref.watch(repositoryQueryProvider));
});

final managementSettingsProvider = Provider<ManagementSettingsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(managementSettingsFutureProvider),
    manualLoading: ref.watch(managementSettingsLoadingProvider), manualError: ref.watch(managementSettingsErrorProvider), manualEmpty: false,
  );
});
