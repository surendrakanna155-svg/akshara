import 'package:akshara_erp/core/repositories/interfaces/platform_operations_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/platform/platform_operations/platform_operations_hub_screen.dart';
import 'package:akshara_erp/features/platform/platform_operations/platform_operations_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

class _FakePlatformOperationsRepository implements PlatformOperationsRepository {
  @override
  Future<ObservabilityDashboard> getObservabilityDashboard({
    required RepositoryQuery query,
  }) async {
    return ObservabilityDashboard(
      kpis: const [
        PlatformKpi(id: 'k1', label: 'Audit Events', value: '100'),
      ],
      auditMetrics: const [
        AuditVisibilityMetric(
          id: 'a1',
          label: 'Upload lag',
          value: '2 min',
          status: 'healthy',
        ),
      ],
      requestTrend: const [MetricTrendPoint(label: 'Mon', value: 100)],
      generatedAt: DateTime(2026, 6, 15),
    );
  }

  @override
  Future<ApplicationHealthSnapshot> getApplicationHealth({
    required RepositoryQuery query,
  }) async {
    return ApplicationHealthSnapshot(
      overallStatus: 'healthy',
      uptimePercent: 99.9,
      services: const [
        ServiceHealthItem(
          id: 'svc1',
          name: 'Core API',
          status: 'healthy',
          uptimePercent: 99.9,
        ),
      ],
      checkedAt: DateTime(2026, 6, 15),
    );
  }

  @override
  Future<ErrorDashboard> getErrorDashboard({
    required RepositoryQuery query,
  }) async {
    return const ErrorDashboard(
      totalErrors24h: 10,
      errorRatePercent: 0.1,
      topErrors: [],
      trend: [],
    );
  }

  @override
  Future<WorkflowMonitoringSnapshot> getWorkflowMonitoring({
    required RepositoryQuery query,
  }) async {
    return const WorkflowMonitoringSnapshot(
      totalFailures24h: 1,
      totalQueueDepth: 5,
      workflows: [],
    );
  }

  @override
  Future<AiMonitoringSnapshot> getAiMonitoring({
    required RepositoryQuery query,
  }) async {
    return const AiMonitoringSnapshot(
      totalInferences24h: 100,
      failureRatePercent: 1,
      avgLatencyMs: 500,
      cacheHitRatePercent: 60,
      providerBreakdown: {},
      latencyTrend: [],
    );
  }

  @override
  Future<PlatformMonitoringSnapshot> getPlatformMonitoring({
    required RepositoryQuery query,
  }) async {
    return const PlatformMonitoringSnapshot(
      overallStatus: 'healthy',
      services: [],
      infrastructureKpis: [],
    );
  }

  @override
  Future<SchoolHealthMonitoringSnapshot> getSchoolHealthMonitoring({
    required RepositoryQuery query,
  }) async {
    return const SchoolHealthMonitoringSnapshot(
      portfolioScore: 80,
      atRiskCount: 0,
      schools: [],
    );
  }

  @override
  Future<SystemMetricsSnapshot> getSystemMetrics({
    required RepositoryQuery query,
  }) async {
    return const SystemMetricsSnapshot(
      cpuPercent: 50,
      memoryPercent: 60,
      requestsPerMinute: 1000,
      cpuTrend: [],
      memoryTrend: [],
      requestTrend: [],
    );
  }

  @override
  Future<List<AlertDefinition>> listAlertDefinitions({
    required RepositoryQuery query,
  }) async {
    return const [];
  }

  @override
  Future<List<PlatformAlert>> listActiveAlerts({
    required RepositoryQuery query,
  }) async {
    return [
      PlatformAlert(
        id: 'plat_alert_1',
        title: 'Test alert',
        message: 'Test message',
        severity: 'high',
        status: 'active',
        triggeredAt: DateTime(2026, 6, 15),
      ),
    ];
  }

  @override
  Future<List<PlatformAlert>> listAlertHistory({
    required RepositoryQuery query,
  }) async {
    return const [];
  }

  @override
  Future<PlatformAlert> acknowledgeAlert({
    required RepositoryQuery query,
    required String alertId,
    String? note,
  }) async {
    return PlatformAlert(
      id: alertId,
      title: 'Test alert',
      message: 'Test message',
      severity: 'high',
      status: 'acknowledged',
      triggeredAt: DateTime(2026, 6, 15),
      ackNote: note,
    );
  }

  @override
  Future<TenantIsolationDashboard> getTenantIsolationDashboard({
    required RepositoryQuery query,
  }) async {
    return TenantIsolationDashboard(
      totalProbes: 213,
      passedProbes: 213,
      boundaryStatus: 'secure',
      probes: const [],
      lastVerifiedAt: DateTime(2026, 6, 15),
    );
  }

  @override
  Future<TenantVerificationReport> runTenantVerification({
    required RepositoryQuery query,
  }) async {
    return TenantVerificationReport(
      reportId: 'tvr_test',
      status: 'completed',
      passedCount: 213,
      failedCount: 0,
      findings: const [],
      completedAt: DateTime(2026, 6, 15),
    );
  }

  @override
  Future<List<TenantDiagnostic>> getTenantDiagnostics({
    required RepositoryQuery query,
  }) async {
    return const [];
  }

  @override
  Future<SecurityDashboard> getSecurityDashboard({
    required RepositoryQuery query,
  }) async {
    return SecurityDashboard(
      kpis: const [],
      threatLevel: 'low',
      openFindings: 0,
      lastScanAt: DateTime(2026, 6, 15),
    );
  }

  @override
  Future<PermissionAuditSummary> getPermissionAuditSummary({
    required RepositoryQuery query,
  }) async {
    return const PermissionAuditSummary(
      totalPermissions: 10,
      anomalyCount: 0,
      rows: [],
    );
  }

  @override
  Future<RoleAuditSummary> getRoleAuditSummary({
    required RepositoryQuery query,
  }) async {
    return const RoleAuditSummary(
      totalRoles: 5,
      staleCount: 0,
      rows: [],
    );
  }

  @override
  Future<List<MutationAuditEntry>> listMutationAudits({
    required RepositoryQuery query,
  }) async {
    return const [];
  }

  @override
  Future<List<PrivilegedAction>> listPrivilegedActions({
    required RepositoryQuery query,
  }) async {
    return const [];
  }

  @override
  Future<List<AccessReviewItem>> listAccessReviews({
    required RepositoryQuery query,
  }) async {
    return const [];
  }

  @override
  Future<AccessReviewItem> completeAccessReview({
    required RepositoryQuery query,
    required String reviewId,
  }) async {
    return AccessReviewItem(
      id: reviewId,
      subject: 'test@akshara.io',
      role: 'financeAdmin',
      dueAt: DateTime(2026, 6, 20),
      status: 'completed',
    );
  }

  @override
  Future<List<SecurityRecommendation>> getSecurityRecommendations({
    required RepositoryQuery query,
  }) async {
    return const [];
  }

  @override
  Future<ProductionReadinessReport> getProductionReadinessReport({
    required RepositoryQuery query,
  }) async {
    return ProductionReadinessReport(
      overallScore: 90,
      status: 'ready',
      categories: const [],
      generatedAt: DateTime(2026, 6, 15),
    );
  }

  @override
  Future<ErrorIntelligenceSnapshot> getErrorIntelligence({
    required RepositoryQuery query,
  }) async {
    return const ErrorIntelligenceSnapshot(
      totalClassified: 0,
      classifications: [],
      spikeAlerts: [],
      trend: [],
    );
  }

  @override
  Future<List<ErrorRecommendation>> getErrorRecommendations({
    required RepositoryQuery query,
  }) async {
    return const [];
  }

  @override
  Future<PlatformHealthIntelligence> getPlatformHealthIntelligence({
    required RepositoryQuery query,
  }) async {
    return PlatformHealthIntelligence(
      overallScore: 85,
      scores: const [],
      riskIndicators: const [],
      aiRecommendations: const [],
      generatedAt: DateTime(2026, 6, 15),
    );
  }
}

void main() {
  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformOperationsRepositoryProvider
              .overrideWithValue(_FakePlatformOperationsRepository()),
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
          rbacServiceProvider.overrideWithValue(
            RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
          ),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const PlatformOperationsHubScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('renders hub with tab smoke for superAdmin', (tester) async {
    await pumpHub(tester);

    expect(find.byKey(QaTestKeys.platformOperationsHubScreen), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Errors'), findsOneWidget);
    expect(find.text('Workflows'), findsOneWidget);
    expect(find.text('AI Monitor'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Tenant'), findsOneWidget);
    expect(find.text('Readiness'), findsOneWidget);
    expect(find.text('Observability'), findsOneWidget);
    expect(find.byKey(QaTestKeys.platformOperationsOperationsHubLink),
        findsOneWidget);

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(find.text('Active Alerts'), findsOneWidget);
    expect(find.byKey(QaTestKeys.platformOperationsAlertTile('plat_alert_1')),
        findsOneWidget);
  });
}
