import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'platform_operations_models.dart';

final platformOperationsCanViewProvider = Provider<bool>((ref) {
  final rbac = ref.watch(rbacServiceProvider);
  return rbac.hasPermission(Permission.viewPlatformOperations);
});

final observabilityDashboardProvider =
    FutureProvider<ObservabilityDashboard>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).getObservabilityDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final applicationHealthProvider =
    FutureProvider<ApplicationHealthSnapshot>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).getApplicationHealth(
        query: ref.watch(repositoryQueryProvider),
      );
});

final errorDashboardProvider = FutureProvider<ErrorDashboard>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).getErrorDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final workflowMonitoringProvider =
    FutureProvider<WorkflowMonitoringSnapshot>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).getWorkflowMonitoring(
        query: ref.watch(repositoryQueryProvider),
      );
});

final aiMonitoringProvider =
    FutureProvider<AiMonitoringSnapshot>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).getAiMonitoring(
        query: ref.watch(repositoryQueryProvider),
      );
});

final platformMonitoringProvider =
    FutureProvider<PlatformMonitoringSnapshot>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).getPlatformMonitoring(
        query: ref.watch(repositoryQueryProvider),
      );
});

final schoolHealthMonitoringProvider =
    FutureProvider<SchoolHealthMonitoringSnapshot>((ref) async {
  return ref
      .read(platformOperationsRepositoryProvider)
      .getSchoolHealthMonitoring(
        query: ref.watch(repositoryQueryProvider),
      );
});

final systemMetricsProvider =
    FutureProvider<SystemMetricsSnapshot>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).getSystemMetrics(
        query: ref.watch(repositoryQueryProvider),
      );
});

final alertDefinitionsProvider =
    FutureProvider<List<AlertDefinition>>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).listAlertDefinitions(
        query: ref.watch(repositoryQueryProvider),
      );
});

final activeAlertsProvider = FutureProvider<List<PlatformAlert>>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).listActiveAlerts(
        query: ref.watch(repositoryQueryProvider),
      );
});

final alertHistoryProvider = FutureProvider<List<PlatformAlert>>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).listAlertHistory(
        query: ref.watch(repositoryQueryProvider),
      );
});

final tenantIsolationDashboardProvider =
    FutureProvider<TenantIsolationDashboard>((ref) async {
  return ref
      .read(platformOperationsRepositoryProvider)
      .getTenantIsolationDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final tenantDiagnosticsProvider =
    FutureProvider<List<TenantDiagnostic>>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).getTenantDiagnostics(
        query: ref.watch(repositoryQueryProvider),
      );
});

final securityDashboardProvider =
    FutureProvider<SecurityDashboard>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).getSecurityDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final permissionAuditSummaryProvider =
    FutureProvider<PermissionAuditSummary>((ref) async {
  return ref
      .read(platformOperationsRepositoryProvider)
      .getPermissionAuditSummary(
        query: ref.watch(repositoryQueryProvider),
      );
});

final roleAuditSummaryProvider =
    FutureProvider<RoleAuditSummary>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).getRoleAuditSummary(
        query: ref.watch(repositoryQueryProvider),
      );
});

final mutationAuditsProvider =
    FutureProvider<List<MutationAuditEntry>>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).listMutationAudits(
        query: ref.watch(repositoryQueryProvider),
      );
});

final privilegedActionsProvider =
    FutureProvider<List<PrivilegedAction>>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).listPrivilegedActions(
        query: ref.watch(repositoryQueryProvider),
      );
});

final accessReviewsProvider =
    FutureProvider<List<AccessReviewItem>>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).listAccessReviews(
        query: ref.watch(repositoryQueryProvider),
      );
});

final securityRecommendationsProvider =
    FutureProvider<List<SecurityRecommendation>>((ref) async {
  return ref
      .read(platformOperationsRepositoryProvider)
      .getSecurityRecommendations(
        query: ref.watch(repositoryQueryProvider),
      );
});

final productionReadinessReportProvider =
    FutureProvider<ProductionReadinessReport>((ref) async {
  return ref
      .read(platformOperationsRepositoryProvider)
      .getProductionReadinessReport(
        query: ref.watch(repositoryQueryProvider),
      );
});

final errorIntelligenceProvider =
    FutureProvider<ErrorIntelligenceSnapshot>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).getErrorIntelligence(
        query: ref.watch(repositoryQueryProvider),
      );
});

final errorRecommendationsProvider =
    FutureProvider<List<ErrorRecommendation>>((ref) async {
  return ref.read(platformOperationsRepositoryProvider).getErrorRecommendations(
        query: ref.watch(repositoryQueryProvider),
      );
});

final platformHealthIntelligenceProvider =
    FutureProvider<PlatformHealthIntelligence>((ref) async {
  return ref
      .read(platformOperationsRepositoryProvider)
      .getPlatformHealthIntelligence(
        query: ref.watch(repositoryQueryProvider),
      );
});
