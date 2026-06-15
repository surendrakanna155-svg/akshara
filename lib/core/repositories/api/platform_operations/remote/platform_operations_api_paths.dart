class PlatformOperationsApiPaths {
  PlatformOperationsApiPaths._();

  static const observabilityDashboard = '/platform-operations/observability';
  static const applicationHealth = '/platform-operations/health/application';
  static const errorDashboard = '/platform-operations/errors/dashboard';
  static const workflowMonitoring = '/platform-operations/workflows/monitoring';
  static const aiMonitoring = '/platform-operations/ai/monitoring';
  static const platformMonitoring = '/platform-operations/platform/monitoring';
  static const schoolHealthMonitoring =
      '/platform-operations/schools/health';
  static const systemMetrics = '/platform-operations/metrics/system';
  static const alertDefinitions = '/platform-operations/alerts/definitions';
  static const activeAlerts = '/platform-operations/alerts/active';
  static const alertHistory = '/platform-operations/alerts/history';
  static String acknowledgeAlert(String alertId) =>
      '/platform-operations/alerts/$alertId/acknowledge';
  static const tenantIsolation = '/platform-operations/tenant/isolation';
  static const tenantVerification = '/platform-operations/tenant/verify';
  static const tenantDiagnostics = '/platform-operations/tenant/diagnostics';
  static const securityDashboard = '/platform-operations/security/dashboard';
  static const permissionAudit = '/platform-operations/security/permissions';
  static const roleAudit = '/platform-operations/security/roles';
  static const mutationAudits = '/platform-operations/security/mutations';
  static const privilegedActions = '/platform-operations/security/privileged';
  static const accessReviews = '/platform-operations/security/access-reviews';
  static String completeAccessReview(String reviewId) =>
      '/platform-operations/security/access-reviews/$reviewId/complete';
  static const securityRecommendations =
      '/platform-operations/security/recommendations';
  static const productionReadiness =
      '/platform-operations/readiness/report';
  static const errorIntelligence = '/platform-operations/errors/intelligence';
  static const errorRecommendations =
      '/platform-operations/errors/recommendations';
  static const platformHealthIntelligence =
      '/platform-operations/health/intelligence';
}
