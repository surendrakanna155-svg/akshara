import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audit/audit_compliance_providers.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme_extensions.dart';
import 'platform_operations_models.dart';
import 'platform_operations_mutations_provider.dart';
import 'platform_operations_providers.dart';
import '../../../theme/spacing.dart';

class PlatformOperationsHubScreen extends ConsumerStatefulWidget {
  const PlatformOperationsHubScreen({
    super.key,
    this.initialTab = 0,
  });

  final int initialTab;

  @override
  ConsumerState<PlatformOperationsHubScreen> createState() =>
      _PlatformOperationsHubScreenState();
}

class _PlatformOperationsHubScreenState
    extends ConsumerState<PlatformOperationsHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 9,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 8),
      animationDuration: Duration.zero,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(platformOperationsCanViewProvider)) {
      return const Scaffold(
        body: Center(
          child: Text('Platform operations permission required.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Operations'),
        bottom: TabBar(
          key: QaTestKeys.platformOperationsTabBar,
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(key: QaTestKeys.platformOperationsOverviewTab, text: 'Overview'),
            Tab(key: QaTestKeys.platformOperationsHealthTab, text: 'Health'),
            Tab(key: QaTestKeys.platformOperationsErrorsTab, text: 'Errors'),
            Tab(
              key: QaTestKeys.platformOperationsWorkflowsTab,
              text: 'Workflows',
            ),
            Tab(key: QaTestKeys.platformOperationsAiTab, text: 'AI Monitor'),
            Tab(key: QaTestKeys.platformOperationsAlertsTab, text: 'Alerts'),
            Tab(key: QaTestKeys.platformOperationsSecurityTab, text: 'Security'),
            Tab(key: QaTestKeys.platformOperationsTenantTab, text: 'Tenant'),
            Tab(
              key: QaTestKeys.platformOperationsReadinessTab,
              text: 'Readiness',
            ),
          ],
        ),
      ),
      body: SizedBox(
        key: QaTestKeys.platformOperationsHubScreen,
        child: TabBarView(
          controller: _tabs,
          children: [
            _overviewTab(ref),
            _healthTab(ref),
            _errorsTab(ref),
            _workflowsTab(ref),
            _aiTab(ref),
            _alertsTab(ref),
            _securityTab(ref),
            _tenantTab(ref),
            _readinessTab(ref),
          ],
        ),
      ),
    );
  }

  Widget _overviewTab(WidgetRef ref) {
    final observability = ref.watch(observabilityDashboardProvider);
    final auditHealth = ref.watch(auditHealthSnapshotProvider);
    return observability.when(
      data: (value) => ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Text('Observability', style: context.aksharaText.titleLarge),
          const SizedBox(height: 12),
          _kpiWrap(value.kpis),
          const Divider(),
          Text('Audit Visibility',
              style: context.aksharaText.titleMedium),
          ...value.auditMetrics.map(
            (metric) => ListTile(
              title: Text(metric.label),
              subtitle: metric.detail != null ? Text(metric.detail!) : null,
              trailing: Text('${metric.value} (${metric.status})'),
            ),
          ),
          auditHealth.when(
            data: (snapshot) => ListTile(
              title: const Text('Audit upload health'),
              subtitle: Text(
                'Pending: ${snapshot.pendingCount} · Failed: ${snapshot.failedCount}',
              ),
            ),
            loading: () => const ListTile(
              title: Text('Audit upload health'),
              trailing: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => ListTile(
              title: const Text('Audit upload health'),
              subtitle: Text('Unavailable: $error'),
            ),
          ),
          const Divider(),
          Text('Cross-links', style: context.aksharaText.titleMedium),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: QaTestKeys.platformOperationsOperationsHubLink,
                onPressed: () => context.go(RouteNames.operationsHub),
                child: const Text('Operations Hub'),
              ),
              TextButton(
                key: QaTestKeys.platformOperationsIntelligenceHubLink,
                onPressed: () => context.go(RouteNames.intelligence),
                child: const Text('Intelligence Hub'),
              ),
              TextButton(
                key: QaTestKeys.platformOperationsDirectorPortalLink,
                onPressed: () => context.go(RouteNames.directorDashboard),
                child: const Text('Director Portal'),
              ),
              TextButton(
                key: QaTestKeys.platformOperationsTrustIntelligenceLink,
                onPressed: () => context.go(RouteNames.organizationIntelligence),
                child: const Text('Trust Intelligence'),
              ),
            ],
          ),
        ],
      ),
      loading: () => const AksharaLoadingState(),
      error: (error, _) => AksharaErrorState.fromFailure(
        apiFailureMapper.fromException(error),
        onRetry: () => ref.invalidate(observabilityDashboardProvider),
      ),
    );
  }

  Widget _healthTab(WidgetRef ref) {
    final appHealth = ref.watch(applicationHealthProvider);
    final platform = ref.watch(platformMonitoringProvider);
    final schools = ref.watch(schoolHealthMonitoringProvider);
    final metrics = ref.watch(systemMetricsProvider);
    final intelligence = ref.watch(platformHealthIntelligenceProvider);
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        appHealth.when(
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Application Health',
                  style: context.aksharaText.titleLarge),
              Text(
                '${value.overallStatus.toUpperCase()} · ${value.uptimePercent}% uptime',
              ),
              ...value.services.map(
                (service) => ListTile(
                  title: Text(service.name),
                  subtitle: Text(service.status),
                  trailing: Text('${service.uptimePercent}%'),
                ),
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('App health error: $error'),
        ),
        const Divider(),
        platform.when(
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform Services',
                  style: context.aksharaText.titleMedium),
              _kpiWrap(value.infrastructureKpis),
              ...value.services.map(
                (service) => ListTile(
                  title: Text(service.name),
                  trailing: Text(service.status),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Platform error: $error'),
        ),
        const Divider(),
        schools.when(
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('School Portfolio (score ${value.portfolioScore})',
                  style: context.aksharaText.titleMedium),
              ...value.schools.map(
                (school) => ListTile(
                  title: Text(school.schoolName),
                  subtitle: Text(school.region ?? school.status),
                  trailing: Text('${school.healthScore}'),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('School health error: $error'),
        ),
        const Divider(),
        metrics.when(
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System Metrics',
                  style: context.aksharaText.titleMedium),
              _kpiWrap([
                PlatformKpi(
                  id: 'cpu',
                  label: 'CPU',
                  value: '${value.cpuPercent}%',
                ),
                PlatformKpi(
                  id: 'memory',
                  label: 'Memory',
                  value: '${value.memoryPercent}%',
                ),
                PlatformKpi(
                  id: 'rpm',
                  label: 'Requests/min',
                  value: '${value.requestsPerMinute}',
                ),
              ]),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Metrics error: $error'),
        ),
        intelligence.when(
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Text('Health Intelligence (score ${value.overallScore})',
                  style: context.aksharaText.titleMedium),
              ...value.scores.map(
                (score) => ListTile(
                  title: Text(score.dimension),
                  trailing: Text('${score.score} · ${score.band}'),
                ),
              ),
              ...value.aiRecommendations.map((rec) => ListTile(title: Text(rec))),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Intelligence error: $error'),
        ),
      ],
    );
  }

  Widget _errorsTab(WidgetRef ref) {
    final dashboard = ref.watch(errorDashboardProvider);
    final intelligence = ref.watch(errorIntelligenceProvider);
    final recommendations = ref.watch(errorRecommendationsProvider);
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        dashboard.when(
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error Dashboard',
                  style: context.aksharaText.titleLarge),
              Text(
                '${value.totalErrors24h} errors · ${value.errorRatePercent}% rate',
              ),
              ...value.topErrors.map(
                (error) => ListTile(
                  title: Text(error.code),
                  subtitle: Text(error.message),
                  trailing: Text('${error.count}'),
                ),
              ),
            ],
          ),
          loading: () => const AksharaLoadingState(),
          error: (error, _) => Text('Dashboard error: $error'),
        ),
        const Divider(),
        intelligence.when(
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error Intelligence',
                  style: context.aksharaText.titleMedium),
              ...value.classifications.map(
                (item) => ListTile(
                  title: Text(item.category),
                  trailing: Text('${item.count} (${item.percent}%)'),
                ),
              ),
              ...value.spikeAlerts.map(
                (alert) => ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: Text(alert),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Intelligence error: $error'),
        ),
        recommendations.when(
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Text('AI Recommendations',
                  style: context.aksharaText.titleMedium),
              ...items.map(
                (item) => ListTile(
                  title: Text(item.title),
                  subtitle: Text(item.detail),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Recommendations error: $error'),
        ),
      ],
    );
  }

  Widget _workflowsTab(WidgetRef ref) {
    final monitoring = ref.watch(workflowMonitoringProvider);
    return monitoring.when(
      data: (value) => ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Text('Workflow Monitoring',
              style: context.aksharaText.titleLarge),
          Text(
            '${value.totalFailures24h} failures · queue depth ${value.totalQueueDepth}',
          ),
          const Divider(),
          ...value.workflows.map(
            (workflow) => ListTile(
              title: Text(workflow.workflowName),
              subtitle: Text(
                'Failed: ${workflow.failedCount} · Queue: ${workflow.queueDepth}',
              ),
              trailing: Text('${workflow.avgDurationSec}s avg'),
            ),
          ),
        ],
      ),
      loading: () => const AksharaLoadingState(),
      error: (error, _) => AksharaErrorState.fromFailure(
        apiFailureMapper.fromException(error),
        onRetry: () => ref.invalidate(workflowMonitoringProvider),
      ),
    );
  }

  Widget _aiTab(WidgetRef ref) {
    final monitoring = ref.watch(aiMonitoringProvider);
    return monitoring.when(
      data: (value) => ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Text('AI Monitoring', style: context.aksharaText.titleLarge),
          _kpiWrap([
            PlatformKpi(
              id: 'inferences',
              label: 'Inferences (24h)',
              value: '${value.totalInferences24h}',
            ),
            PlatformKpi(
              id: 'failure_rate',
              label: 'Failure Rate',
              value: '${value.failureRatePercent}%',
            ),
            PlatformKpi(
              id: 'latency',
              label: 'Avg Latency',
              value: '${value.avgLatencyMs}ms',
            ),
            PlatformKpi(
              id: 'cache',
              label: 'Cache Hit Rate',
              value: '${value.cacheHitRatePercent}%',
            ),
          ]),
          const Divider(),
          Text('Provider Breakdown',
              style: context.aksharaText.titleMedium),
          ...value.providerBreakdown.entries.map(
            (entry) => ListTile(
              title: Text(entry.key),
              trailing: Text('${entry.value}'),
            ),
          ),
        ],
      ),
      loading: () => const AksharaLoadingState(),
      error: (error, _) => AksharaErrorState.fromFailure(
        apiFailureMapper.fromException(error),
        onRetry: () => ref.invalidate(aiMonitoringProvider),
      ),
    );
  }

  Widget _alertsTab(WidgetRef ref) {
    final active = ref.watch(activeAlertsProvider);
    final history = ref.watch(alertHistoryProvider);
    final definitions = ref.watch(alertDefinitionsProvider);
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        Text('Active Alerts', style: context.aksharaText.titleLarge),
        active.when(
          data: (alerts) => Column(
            children: alerts
                .map((alert) => _alertTile(ref, alert, showAck: true))
                .toList(growable: false),
          ),
          loading: () => const AksharaLoadingState(),
          error: (error, _) => Text('Active alerts error: $error'),
        ),
        const Divider(),
        Text('Alert History', style: context.aksharaText.titleMedium),
        history.when(
          data: (alerts) => Column(
            children: alerts
                .map((alert) => _alertTile(ref, alert, showAck: false))
                .toList(growable: false),
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('History error: $error'),
        ),
        const Divider(),
        definitions.when(
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alert Definitions',
                  style: context.aksharaText.titleMedium),
              ...items.map(
                (def) => ListTile(
                  title: Text(def.name),
                  subtitle: Text('${def.metric} · ${def.threshold}'),
                  trailing: Text(def.enabled ? 'ON' : 'OFF'),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Definitions error: $error'),
        ),
      ],
    );
  }

  Widget _alertTile(WidgetRef ref, PlatformAlert alert, {required bool showAck}) {
    return ListTile(
      key: QaTestKeys.platformOperationsAlertTile(alert.id),
      title: Text(alert.title),
      subtitle: Text('${alert.severity} · ${alert.message}'),
      trailing: showAck && alert.status == 'active'
          ? TextButton(
              key: QaTestKeys.platformOperationsAcknowledgeAlertButton(alert.id),
              onPressed: () => _acknowledgeAlert(ref, alert.id),
              child: const Text('Ack'),
            )
          : Text(alert.status),
    );
  }

  Future<void> _acknowledgeAlert(WidgetRef ref, String alertId) async {
    await ref.read(acknowledgeAlertProvider.notifier).execute(
          alertId: alertId,
          note: 'Acknowledged from Platform Ops hub',
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.platformOperationsAlertAcknowledgedSnackbar,
          content: Text('Alert $alertId acknowledged'),
        ),
      );
    }
  }

  Widget _securityTab(WidgetRef ref) {
    final dashboard = ref.watch(securityDashboardProvider);
    final permissions = ref.watch(permissionAuditSummaryProvider);
    final roles = ref.watch(roleAuditSummaryProvider);
    final mutations = ref.watch(mutationAuditsProvider);
    final privileged = ref.watch(privilegedActionsProvider);
    final recommendations = ref.watch(securityRecommendationsProvider);
    final reviews = ref.watch(accessReviewsProvider);
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        dashboard.when(
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Security Dashboard',
                  style: context.aksharaText.titleLarge),
              Text(
                'Threat: ${value.threatLevel} · ${value.openFindings} open findings',
              ),
              _kpiWrap(value.kpis),
            ],
          ),
          loading: () => const AksharaLoadingState(),
          error: (error, _) => Text('Security error: $error'),
        ),
        permissions.when(
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Text('Permission Audit (${value.anomalyCount} anomalies)',
                  style: context.aksharaText.titleMedium),
              ...value.rows.map(
                (row) => ListTile(
                  title: Text(row.permission),
                  trailing: Text(
                    '${row.userCount} users${row.anomalyFlag ? ' ⚠' : ''}',
                  ),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Permission audit error: $error'),
        ),
        roles.when(
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Text('Role Audit (${value.staleCount} stale)',
                  style: context.aksharaText.titleMedium),
              ...value.rows.map(
                (row) => ListTile(
                  title: Text(row.role),
                  subtitle: Text('${row.permissionCount} permissions'),
                  trailing: Text(row.stale ? 'Stale' : 'OK'),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Role audit error: $error'),
        ),
        mutations.when(
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Text('Mutation Audits',
                  style: context.aksharaText.titleMedium),
              ...items.map(
                (item) => ListTile(
                  title: Text(item.mutationId),
                  subtitle: Text('${item.actor} · ${item.module}'),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Mutation audit error: $error'),
        ),
        privileged.when(
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Text('Privileged Actions',
                  style: context.aksharaText.titleMedium),
              ...items.map(
                (item) => ListTile(
                  title: Text(item.action),
                  subtitle: Text('${item.actor} → ${item.target}'),
                  trailing: Text(item.riskLevel),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Privileged actions error: $error'),
        ),
        reviews.when(
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Text('Access Reviews',
                  style: context.aksharaText.titleMedium),
              ...items.map(
                (item) => ListTile(
                  key: QaTestKeys.platformOperationsAccessReviewTile(item.id),
                  title: Text(item.subject),
                  subtitle: Text('${item.role} · due ${item.dueAt}'),
                  trailing: item.status == 'pending'
                      ? TextButton(
                          key: QaTestKeys
                              .platformOperationsCompleteAccessReviewButton(
                            item.id,
                          ),
                          onPressed: () => _completeAccessReview(ref, item.id),
                          child: const Text('Complete'),
                        )
                      : Text(item.status),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Access reviews error: $error'),
        ),
        recommendations.when(
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Text('Security Recommendations',
                  style: context.aksharaText.titleMedium),
              ...items.map(
                (item) => ListTile(
                  title: Text(item.title),
                  subtitle: Text(item.detail),
                  trailing: Text(item.priority),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Recommendations error: $error'),
        ),
      ],
    );
  }

  Future<void> _completeAccessReview(WidgetRef ref, String reviewId) async {
    await ref
        .read(completeAccessReviewProvider.notifier)
        .execute(reviewId: reviewId);
  }

  Widget _tenantTab(WidgetRef ref) {
    final isolation = ref.watch(tenantIsolationDashboardProvider);
    final diagnostics = ref.watch(tenantDiagnosticsProvider);
    final verificationState = ref.watch(runTenantVerificationProvider);
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        isolation.when(
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tenant Isolation',
                  style: context.aksharaText.titleLarge),
              Text(
                '${value.passedProbes}/${value.totalProbes} probes passed · ${value.boundaryStatus}',
              ),
              FilledButton(
                key: QaTestKeys.platformOperationsRunTenantVerificationButton,
                onPressed: () => ref
                    .read(runTenantVerificationProvider.notifier)
                    .execute(),
                child: const Text('Run Verification'),
              ),
              ...value.probes.map(
                (probe) => ListTile(
                  title: Text(probe.label),
                  subtitle: Text(probe.detail),
                  trailing: Icon(
                    probe.passed ? Icons.check_circle : Icons.error,
                    color: probe.passed
                        ? context.akshara.success
                        : context.colors.error,
                  ),
                ),
              ),
            ],
          ),
          loading: () => const AksharaLoadingState(),
          error: (error, _) => Text('Isolation error: $error'),
        ),
        if (verificationState.hasValue && verificationState.value != null)
          ListTile(
            title: Text('Last verification: ${verificationState.value!.status}'),
            subtitle: Text(
              'Passed ${verificationState.value!.passedCount} · Failed ${verificationState.value!.failedCount}',
            ),
          ),
        const Divider(),
        diagnostics.when(
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tenant Diagnostics',
                  style: context.aksharaText.titleMedium),
              ...items.map(
                (item) => ListTile(
                  title: Text(item.tenantName),
                  subtitle: Text(item.issues.join(' · ')),
                  trailing: Text('${item.isolationScore}'),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Text('Diagnostics error: $error'),
        ),
      ],
    );
  }

  Widget _readinessTab(WidgetRef ref) {
    final report = ref.watch(productionReadinessReportProvider);
    return report.when(
      data: (value) => ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Text('Production Readiness',
              style: context.aksharaText.titleLarge),
          Text(
            'Score ${value.overallScore} · ${value.status}',
            style: context.aksharaText.titleMedium,
          ),
          const Divider(),
          ...value.categories.map(
            (category) => ExpansionTile(
              key: QaTestKeys.platformOperationsReadinessCategory(category.id),
              title: Text('${category.name} (${category.score})'),
              children: category.items
                  .map(
                    (item) => ListTile(
                      leading: Icon(
                        item.passed ? Icons.check : Icons.close,
                        color: item.passed
                            ? context.akshara.success
                            : context.colors.error,
                      ),
                      title: Text(item.label),
                      subtitle:
                          item.detail != null ? Text(item.detail!) : null,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
      loading: () => const AksharaLoadingState(),
      error: (error, _) => AksharaErrorState.fromFailure(
        apiFailureMapper.fromException(error),
        onRetry: () => ref.invalidate(productionReadinessReportProvider),
      ),
    );
  }

  Widget _kpiWrap(List<PlatformKpi> kpis) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final kpi in kpis)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kpi.label, style: context.aksharaText.labelSmall),
                  Text(kpi.value, style: context.aksharaText.titleMedium),
                  if (kpi.deltaLabel != null)
                    Text(kpi.deltaLabel!, style: context.aksharaText.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
