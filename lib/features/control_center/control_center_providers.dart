import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tenant/tenant_provider.dart';
import '../../core/providers/repository_future.dart';

import '../../core/repositories/paginated_result.dart';
import '../../core/repositories/repository_providers.dart';
import 'control_center_models.dart';

// ACC-01 Dashboard
final controlCenterDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final controlCenterDashboardErrorProvider = StateProvider<bool>((ref) => false);
final controlCenterDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final controlCenterDashboardFilterProvider = StateProvider<int>((ref) => 0);

final controlCenterDashboardFutureProvider = FutureProvider<ControlCenterDashboardData>((ref) async {
return await ref.read(controlCenterRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

final controlCenterDashboardProvider = Provider<ControlCenterDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(controlCenterDashboardFutureProvider),
    manualLoading: ref.watch(controlCenterDashboardLoadingProvider), manualError: ref.watch(controlCenterDashboardErrorProvider), manualEmpty: ref.watch(controlCenterDashboardEmptyProvider),
  );
});

// ACC-02 Schools
final controlCenterSchoolsLoadingProvider = StateProvider<bool>((ref) => false);
final controlCenterSchoolsErrorProvider = StateProvider<bool>((ref) => false);
final controlCenterSchoolsEmptyProvider = StateProvider<bool>((ref) => false);
final controlCenterSchoolsFilterProvider = StateProvider<int>((ref) => 0);

final controlCenterSchoolsFutureProvider = FutureProvider<PaginatedResult<PlatformSchool>>((ref) async {
return ref.read(controlCenterRepositoryProvider).getSchools(query: ref.watch(repositoryQueryProvider));
});

final controlCenterSchoolsProvider = Provider<List<PlatformSchool>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(controlCenterSchoolsFutureProvider),
    manualLoading: ref.watch(controlCenterSchoolsLoadingProvider), manualError: ref.watch(controlCenterSchoolsErrorProvider), manualEmpty: ref.watch(controlCenterSchoolsEmptyProvider),
  )?.items ?? const [];
});

final controlCenterFilteredSchoolsProvider = Provider<List<PlatformSchool>>(
  (ref) {
    final schools = ref.watch(controlCenterSchoolsProvider);
    if (schools == null) return const [];
    final filterIndex = ref.watch(controlCenterSchoolsFilterProvider);
    return switch (filterIndex) {
      1 => schools
          .where((s) => s.status == PlatformSchoolStatus.active)
          .toList(),
      2 => schools
          .where((s) => s.status == PlatformSchoolStatus.trial)
          .toList(),
      3 => schools
          .where((s) => s.status == PlatformSchoolStatus.churnRisk)
          .toList(),
      _ => schools,
    };
  },
);

// ACC-03 Subscriptions
final controlCenterSubscriptionsLoadingProvider =
    StateProvider<bool>((ref) => false);
final controlCenterSubscriptionsErrorProvider =
    StateProvider<bool>((ref) => false);

final controlCenterSubscriptionsFutureProvider =
    FutureProvider<ControlCenterSubscriptionsData>((ref) async {
  return ref.read(controlCenterRepositoryProvider).getSubscriptions(
        query: ref.watch(repositoryQueryProvider),
      );
});

final controlCenterSubscriptionsProvider =
    Provider<ControlCenterSubscriptionsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(controlCenterSubscriptionsFutureProvider),
    manualLoading: ref.watch(controlCenterSubscriptionsLoadingProvider),
    manualError: ref.watch(controlCenterSubscriptionsErrorProvider),
    manualEmpty: false,
  );
});

// ACC-04 Billing
final controlCenterBillingLoadingProvider = StateProvider<bool>((ref) => false);
final controlCenterBillingErrorProvider = StateProvider<bool>((ref) => false);

final controlCenterBillingFutureProvider = FutureProvider<ControlCenterBillingData>((ref) async {
return await ref.read(controlCenterRepositoryProvider).getBilling(query: ref.watch(repositoryQueryProvider));
});

final controlCenterBillingProvider = Provider<ControlCenterBillingData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(controlCenterBillingFutureProvider),
    manualLoading: ref.watch(controlCenterBillingLoadingProvider), manualError: ref.watch(controlCenterBillingErrorProvider), manualEmpty: false,
  );
});

// ACC-05 CRM
final controlCenterCrmLoadingProvider = StateProvider<bool>((ref) => false);
final controlCenterCrmErrorProvider = StateProvider<bool>((ref) => false);
final controlCenterCrmFilterProvider = StateProvider<int>((ref) => 0);

final controlCenterCrmFutureProvider = FutureProvider<ControlCenterCrmData>((ref) async {
return await ref.read(controlCenterRepositoryProvider).getCrmPipeline(query: ref.watch(repositoryQueryProvider));
});

final controlCenterCrmProvider = Provider<ControlCenterCrmData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(controlCenterCrmFutureProvider),
    manualLoading: ref.watch(controlCenterCrmLoadingProvider), manualError: ref.watch(controlCenterCrmErrorProvider), manualEmpty: false,
  );
});

// ACC-06 Support
final controlCenterSupportLoadingProvider = StateProvider<bool>((ref) => false);
final controlCenterSupportErrorProvider = StateProvider<bool>((ref) => false);
final controlCenterSupportEmptyProvider = StateProvider<bool>((ref) => false);
final controlCenterSupportFilterProvider = StateProvider<int>((ref) => 0);

final controlCenterSupportFutureProvider = FutureProvider<PaginatedResult<SupportTicket>>((ref) async {
return ref.read(controlCenterRepositoryProvider).getSupportTickets(query: ref.watch(repositoryQueryProvider));
});

final controlCenterSupportProvider = Provider<List<SupportTicket>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(controlCenterSupportFutureProvider),
    manualLoading: ref.watch(controlCenterSupportLoadingProvider), manualError: ref.watch(controlCenterSupportErrorProvider), manualEmpty: ref.watch(controlCenterSupportEmptyProvider),
  )?.items ?? const [];
});

final controlCenterFilteredSupportProvider = Provider<List<SupportTicket>>(
  (ref) {
    final tickets = ref.watch(controlCenterSupportProvider);
    if (tickets == null) return const [];
    final filterIndex = ref.watch(controlCenterSupportFilterProvider);
    return switch (filterIndex) {
      1 => tickets
          .where((t) => t.status == SupportTicketStatus.open)
          .toList(),
      2 => tickets
          .where((t) => t.status == SupportTicketStatus.inProgress)
          .toList(),
      3 => tickets
          .where((t) => t.status == SupportTicketStatus.resolved)
          .toList(),
      _ => tickets,
    };
  },
);

// ACC-07 Success
final controlCenterSuccessLoadingProvider = StateProvider<bool>((ref) => false);
final controlCenterSuccessErrorProvider = StateProvider<bool>((ref) => false);

final controlCenterSuccessFutureProvider = FutureProvider<ControlCenterSuccessData>((ref) async {
return await ref.read(controlCenterRepositoryProvider).getCustomerSuccess(query: ref.watch(repositoryQueryProvider));
});

final controlCenterSuccessProvider = Provider<ControlCenterSuccessData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(controlCenterSuccessFutureProvider),
    manualLoading: ref.watch(controlCenterSuccessLoadingProvider), manualError: ref.watch(controlCenterSuccessErrorProvider), manualEmpty: false,
  );
});

// ACC-08 White Label
final controlCenterWhiteLabelLoadingProvider =
    StateProvider<bool>((ref) => false);
final controlCenterWhiteLabelErrorProvider =
    StateProvider<bool>((ref) => false);

final controlCenterWhiteLabelFutureProvider =
    FutureProvider<PaginatedResult<WhiteLabelConfig>>((ref) async {
  return ref.read(controlCenterRepositoryProvider).getWhiteLabelConfigs(
        query: ref.watch(repositoryQueryProvider),
      );
});

final controlCenterWhiteLabelProvider = Provider<List<WhiteLabelConfig>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(controlCenterWhiteLabelFutureProvider),
    manualLoading: ref.watch(controlCenterWhiteLabelLoadingProvider),
    manualError: ref.watch(controlCenterWhiteLabelErrorProvider),
    manualEmpty: false,
  )?.items ?? const [];
});

// ACC-09 Analytics
final controlCenterAnalyticsLoadingProvider =
    StateProvider<bool>((ref) => false);
final controlCenterAnalyticsErrorProvider = StateProvider<bool>((ref) => false);

final controlCenterAnalyticsFutureProvider =
    FutureProvider<ControlCenterAnalyticsData>((ref) async {
  return ref.read(controlCenterRepositoryProvider).getAnalytics(
        query: ref.watch(repositoryQueryProvider),
      );
});

final controlCenterAnalyticsProvider =
    Provider<ControlCenterAnalyticsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(controlCenterAnalyticsFutureProvider),
    manualLoading: ref.watch(controlCenterAnalyticsLoadingProvider),
    manualError: ref.watch(controlCenterAnalyticsErrorProvider),
    manualEmpty: false,
  );
});

// ACC-10 Monitoring
final controlCenterMonitoringLoadingProvider =
    StateProvider<bool>((ref) => false);
final controlCenterMonitoringErrorProvider =
    StateProvider<bool>((ref) => false);

final controlCenterMonitoringFutureProvider =
    FutureProvider<ControlCenterMonitoringData>((ref) async {
  return ref.read(controlCenterRepositoryProvider).getMonitoring(
        query: ref.watch(repositoryQueryProvider),
      );
});

final controlCenterMonitoringProvider =
    Provider<ControlCenterMonitoringData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(controlCenterMonitoringFutureProvider),
    manualLoading: ref.watch(controlCenterMonitoringLoadingProvider),
    manualError: ref.watch(controlCenterMonitoringErrorProvider),
    manualEmpty: false,
  );
});

// ACC-11 Roles
final controlCenterRolesLoadingProvider = StateProvider<bool>((ref) => false);
final controlCenterRolesErrorProvider = StateProvider<bool>((ref) => false);

final controlCenterRolesFutureProvider = FutureProvider<ControlCenterRolesData>((ref) async {
return await ref.read(controlCenterRepositoryProvider).getRoles(query: ref.watch(repositoryQueryProvider));
});

final controlCenterRolesProvider = Provider<ControlCenterRolesData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(controlCenterRolesFutureProvider),
    manualLoading: ref.watch(controlCenterRolesLoadingProvider), manualError: ref.watch(controlCenterRolesErrorProvider), manualEmpty: false,
  );
});

// ACC-12 Settings
final controlCenterSettingsLoadingProvider =
    StateProvider<bool>((ref) => false);
final controlCenterSettingsErrorProvider = StateProvider<bool>((ref) => false);

final controlCenterSettingsFutureProvider = FutureProvider<ControlCenterSettingsData>((ref) async {
return await ref.read(controlCenterRepositoryProvider).getSettings(query: ref.watch(repositoryQueryProvider));
});

final controlCenterSettingsProvider = Provider<ControlCenterSettingsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(controlCenterSettingsFutureProvider),
    manualLoading: ref.watch(controlCenterSettingsLoadingProvider), manualError: ref.watch(controlCenterSettingsErrorProvider), manualEmpty: false,
  );
});
