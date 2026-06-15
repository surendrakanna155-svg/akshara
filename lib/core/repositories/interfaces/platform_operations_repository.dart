import '../../../features/platform_operations/platform_operations_models.dart';
import '../repository_query.dart';

abstract class PlatformOperationsRepository {
  Future<ObservabilityDashboard> getObservabilityDashboard({
    required RepositoryQuery query,
  });

  Future<ApplicationHealthSnapshot> getApplicationHealth({
    required RepositoryQuery query,
  });

  Future<ErrorDashboard> getErrorDashboard({
    required RepositoryQuery query,
  });

  Future<WorkflowMonitoringSnapshot> getWorkflowMonitoring({
    required RepositoryQuery query,
  });

  Future<AiMonitoringSnapshot> getAiMonitoring({
    required RepositoryQuery query,
  });

  Future<PlatformMonitoringSnapshot> getPlatformMonitoring({
    required RepositoryQuery query,
  });

  Future<SchoolHealthMonitoringSnapshot> getSchoolHealthMonitoring({
    required RepositoryQuery query,
  });

  Future<SystemMetricsSnapshot> getSystemMetrics({
    required RepositoryQuery query,
  });

  Future<List<AlertDefinition>> listAlertDefinitions({
    required RepositoryQuery query,
  });

  Future<List<PlatformAlert>> listActiveAlerts({
    required RepositoryQuery query,
  });

  Future<List<PlatformAlert>> listAlertHistory({
    required RepositoryQuery query,
  });

  Future<PlatformAlert> acknowledgeAlert({
    required RepositoryQuery query,
    required String alertId,
    String? note,
  });

  Future<TenantIsolationDashboard> getTenantIsolationDashboard({
    required RepositoryQuery query,
  });

  Future<TenantVerificationReport> runTenantVerification({
    required RepositoryQuery query,
  });

  Future<List<TenantDiagnostic>> getTenantDiagnostics({
    required RepositoryQuery query,
  });

  Future<SecurityDashboard> getSecurityDashboard({
    required RepositoryQuery query,
  });

  Future<PermissionAuditSummary> getPermissionAuditSummary({
    required RepositoryQuery query,
  });

  Future<RoleAuditSummary> getRoleAuditSummary({
    required RepositoryQuery query,
  });

  Future<List<MutationAuditEntry>> listMutationAudits({
    required RepositoryQuery query,
  });

  Future<List<PrivilegedAction>> listPrivilegedActions({
    required RepositoryQuery query,
  });

  Future<List<AccessReviewItem>> listAccessReviews({
    required RepositoryQuery query,
  });

  Future<AccessReviewItem> completeAccessReview({
    required RepositoryQuery query,
    required String reviewId,
  });

  Future<List<SecurityRecommendation>> getSecurityRecommendations({
    required RepositoryQuery query,
  });

  Future<ProductionReadinessReport> getProductionReadinessReport({
    required RepositoryQuery query,
  });

  Future<ErrorIntelligenceSnapshot> getErrorIntelligence({
    required RepositoryQuery query,
  });

  Future<List<ErrorRecommendation>> getErrorRecommendations({
    required RepositoryQuery query,
  });

  Future<PlatformHealthIntelligence> getPlatformHealthIntelligence({
    required RepositoryQuery query,
  });
}
