import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_layout.dart';
import '../../admin/admin_shell.dart';
import '../../admin/models/admin_nav_models.dart';
import 'intelligence_models.dart';
import 'intelligence_provider.dart';
import '../../intelligence/operations/operations_intelligence_provider.dart';
import '../../intelligence/unified/unified_recommendation_intelligence.dart';
import '../../intelligence/unified/unified_recommendations_provider.dart';
import 'intelligence_recommendation_navigation.dart';

/// Analytics & Intelligence hub — dashboard, health, risks, trends, principal summary (v7.6).
class IntelligenceHubScreen extends ConsumerStatefulWidget {
  const IntelligenceHubScreen({super.key});

  @override
  ConsumerState<IntelligenceHubScreen> createState() =>
      _IntelligenceHubScreenState();
}

class _IntelligenceHubScreenState extends ConsumerState<IntelligenceHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(intelligenceCanViewProvider)) {
      return const Scaffold(
        body: AksharaErrorState(
          message: 'Analytics & Intelligence is not enabled for your role.',
          icon: Icons.lock_outline,
        ),
      );
    }

    return AdminContentScaffold(
      breadcrumbs: const [
        AdminBreadcrumb(label: 'Management', route: '/management/dashboard'),
        AdminBreadcrumb(label: 'Analytics & Intelligence'),
      ],
      onMenuTap: adminShellMenuTap(context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final tabHeight =
              (MediaQuery.sizeOf(context).height * 0.65).clamp(360.0, 720.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabBar(
                controller: _tabs,
                isScrollable: AdminLayout.isMobile(context),
                tabs: const [
                  Tab(text: 'Analytics'),
                  Tab(text: 'School Health'),
                  Tab(text: 'Risk Center'),
                  Tab(text: 'Trends'),
                  Tab(text: 'Recommendations'),
                  Tab(text: 'Principal Summary'),
                ],
              ),
              SizedBox(
                height: tabHeight,
                child: TabBarView(
                  controller: _tabs,
                  children: const [
                    _AnalyticsDashboardTab(),
                    _SchoolHealthTab(),
                    _RiskCenterTab(),
                    _TrendExplorerTab(),
                    _UnifiedRecommendationsTab(),
                    _PrincipalSummaryTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsDashboardTab extends ConsumerWidget {
  const _AnalyticsDashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(intelligenceDashboardProvider);
    return metricsAsync.when(
      loading: () => const AksharaLoadingState(
          semanticLabel: 'Loading analytics dashboard'),
      error: (_, __) => AksharaErrorState(
        message: 'Unable to load analytics dashboard.',
        onRetry: () => invalidateIntelligenceReads(ref),
      ),
      data: (metrics) => ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          const AksharaSectionHeader(title: 'Risk signals'),
          Wrap(
            spacing: AksharaSpacing.s3,
            runSpacing: AksharaSpacing.s3,
            children: [
              _KpiCard(
                  label: 'Student risk', value: '${metrics.studentRiskScore}'),
              _KpiCard(
                  label: 'Attendance risk',
                  value: '${metrics.attendanceRiskScore}'),
              _KpiCard(
                  label: 'Academic risk',
                  value: '${metrics.academicPerformanceRisk}'),
              _KpiCard(
                  label: 'Fee collection risk',
                  value: '${metrics.feeCollectionRisk}'),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s6),
          const AksharaSectionHeader(title: 'Operational metrics'),
          Wrap(
            spacing: AksharaSpacing.s3,
            runSpacing: AksharaSpacing.s3,
            children: [
              _KpiCard(
                  label: 'Admissions conversion',
                  value: '${metrics.admissionConversionRate}%'),
              _KpiCard(
                  label: 'Teacher workload',
                  value: '${metrics.teacherWorkloadIndex}'),
              _KpiCard(
                  label: 'Timetable health',
                  value: '${metrics.timetableHealthScore}'),
              _KpiCard(
                  label: 'Communication engagement',
                  value: '${metrics.communicationEngagementScore}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SchoolHealthTab extends ConsumerWidget {
  const _SchoolHealthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(intelligenceCanViewHealthProvider)) {
      return const AksharaErrorState(
        message: 'School health scores require viewSchoolHealth permission.',
        icon: Icons.lock_outline,
      );
    }

    final healthAsync = ref.watch(intelligenceHealthProvider);
    return healthAsync.when(
      loading: () =>
          const AksharaLoadingState(semanticLabel: 'Loading school health'),
      error: (_, __) => AksharaErrorState(
        message: 'Unable to load school health summary.',
        onRetry: () => invalidateIntelligenceReads(ref),
      ),
      data: (health) => ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          _KpiCard(
              label: 'School health score',
              value: '${health.schoolHealthScore}'),
          const SizedBox(height: AksharaSpacing.s4),
          Wrap(
            spacing: AksharaSpacing.s3,
            runSpacing: AksharaSpacing.s3,
            children: [
              _KpiCard(label: 'Academic', value: '${health.academicHealth}'),
              _KpiCard(label: 'Finance', value: '${health.financeHealth}'),
              _KpiCard(
                  label: 'Operations', value: '${health.operationsHealth}'),
              _KpiCard(
                  label: 'Engagement', value: '${health.engagementHealth}'),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s6),
          const AksharaSectionHeader(title: 'Score composition'),
          for (final component in health.composition) ...[
            Card(
              child: ListTile(
                title: Text(component.label),
                subtitle: Text(
                  'Score ${component.score} · weight ${(component.weight * 100).round()}%\n${component.detail}',
                ),
                trailing: Text('${component.score}'),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s2),
          ],
        ],
      ),
    );
  }
}

class _RiskCenterTab extends ConsumerWidget {
  const _RiskCenterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risksAsync = ref.watch(intelligenceRisksProvider);
    return risksAsync.when(
      loading: () =>
          const AksharaLoadingState(semanticLabel: 'Loading risk summaries'),
      error: (_, __) => AksharaErrorState(
        message: 'Unable to load risk summaries.',
        onRetry: () => invalidateIntelligenceReads(ref),
      ),
      data: (bundle) {
        if (bundle.items.isEmpty) {
          return const AksharaEmptyState(
            message: 'No risk metrics available.',
            icon: Icons.shield_outlined,
          );
        }
        return ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            const AksharaSectionHeader(title: 'Risk summaries'),
            for (final risk in bundle.items)
              Card(
                child: ListTile(
                  leading: Icon(_iconForRisk(risk.level),
                      color: _colorForRisk(risk.level)),
                  title: Text(risk.label),
                  subtitle: Text('Score ${risk.score} · ${risk.detail}'),
                  trailing: Text(risk.level.name.toUpperCase()),
                ),
              ),
            if (bundle.anomalies.isNotEmpty) ...[
              const SizedBox(height: AksharaSpacing.s6),
              const AksharaSectionHeader(title: 'Anomalies'),
              for (final anomaly in bundle.anomalies)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_outlined),
                    title: Text(anomaly.metric),
                    subtitle: Text(anomaly.detail),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _TrendExplorerTab extends ConsumerWidget {
  const _TrendExplorerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(intelligenceTrendsProvider);
    return trendsAsync.when(
      loading: () =>
          const AksharaLoadingState(semanticLabel: 'Loading trend analysis'),
      error: (_, __) => AksharaErrorState(
        message: 'Unable to load trend analysis.',
        onRetry: () => invalidateIntelligenceReads(ref),
      ),
      data: (bundle) {
        if (bundle.series.isEmpty) {
          return const AksharaEmptyState(
            message: 'No trend series available.',
            icon: Icons.show_chart,
          );
        }
        return ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            for (final entry in bundle.series.entries) ...[
              AksharaSectionHeader(title: _seriesTitle(entry.key)),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AksharaSpacing.s3),
                  child: Column(
                    children: [
                      for (final point in entry.value)
                        ListTile(
                          dense: true,
                          title: Text(point.period),
                          trailing: Text(
                            point.benchmark == null
                                ? '${point.value}'
                                : '${point.value} / ${point.benchmark}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AksharaSpacing.s4),
            ],
          ],
        );
      },
    );
  }
}

class _UnifiedRecommendationsTab extends ConsumerWidget {
  const _UnifiedRecommendationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unified = ref.watch(unifiedRecommendationSummaryProvider);
    final operations = ref.watch(operationsIntelligenceSummaryProvider);

    return unified.when(
      loading: () =>
          const AksharaLoadingState(semanticLabel: 'Loading recommendations'),
      error: (_, __) => AksharaErrorState(
        message: 'Unable to load unified recommendations.',
        onRetry: () {
          ref.invalidate(unifiedRecommendationsProvider);
          ref.invalidate(operationsIntelligenceHintsProvider);
        },
      ),
      data: (summary) {
        if (summary.topRecommendations.isEmpty) {
          return const AksharaEmptyState(
            message:
                'No cross-module recommendations yet. Run intelligence compute on student and finance modules.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            Text(
              '${summary.totalRecommendations} recommendations · ${summary.criticalCount} critical',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AksharaSpacing.s3),
            for (final item in summary.topRecommendations)
              Material(
                elevation: 0,
                color: context.colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AksharaRadius.card,
                  side: BorderSide(color: context.colors.outlineVariant),
                ),
                child: ListTile(
                  leading: Icon(
                    _iconForRecommendationSource(item.source),
                    color: context.colors.primary,
                  ),
                  onTap: () =>
                      navigateIntelligenceRecommendation(context, item.source),
                  title: Text(
                    item.title,
                    style: context.aksharaText.titleSmall,
                  ),
                  subtitle: Text(
                    '${item.source.label} · Priority ${item.priorityScore}\n'
                    '${item.detail}\n${item.suggestedAction}',
                    style: context.aksharaText.bodySmall.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  isThreeLine: true,
                ),
              ),
            operations.when(
              data: (ops) {
                if (ops.topHints.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AksharaSectionHeader(
                        title: 'Operations intelligence (P2)'),
                    ListTile(
                      dense: true,
                      title: Text(
                        'Section balance ${ops.sectionBalanceCount} · '
                        'Teacher continuity ${ops.teacherContinuityCount} · '
                        'Workflow ${ops.workflowCount}',
                      ),
                    ),
                    for (final hint in ops.topHints)
                      ListTile(
                        leading: const Icon(Icons.settings_suggest_outlined),
                        onTap: () => navigateOperationsHint(context, hint.kind),
                        title: Text('${hint.kind.label}: ${hint.title}'),
                        subtitle:
                            Text('${hint.detail}\n${hint.suggestedAction}'),
                        isThreeLine: true,
                      ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

IconData _iconForRecommendationSource(UnifiedRecommendationSource source) =>
    switch (source) {
      UnifiedRecommendationSource.atRisk => Icons.person_off_outlined,
      UnifiedRecommendationSource.attendance => Icons.event_busy_outlined,
      UnifiedRecommendationSource.feeCollection => Icons.payments_outlined,
      UnifiedRecommendationSource.teacherIntervention => Icons.school_outlined,
      UnifiedRecommendationSource.promotion => Icons.upgrade_outlined,
      UnifiedRecommendationSource.operations => Icons.settings_suggest_outlined,
    };

class _PrincipalSummaryTab extends ConsumerWidget {
  const _PrincipalSummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(intelligenceCanViewHealthProvider)) {
      return const AksharaErrorState(
        message: 'Principal summary requires viewSchoolHealth permission.',
        icon: Icons.lock_outline,
      );
    }

    final summaryAsync = ref.watch(intelligencePrincipalSummaryProvider);
    final briefingAsync = ref.watch(intelligenceWeeklyBriefingProvider);
    final recommendationsAsync = ref.watch(intelligenceRecommendationsProvider);

    return summaryAsync.when(
      loading: () =>
          const AksharaLoadingState(semanticLabel: 'Loading principal summary'),
      error: (_, __) => AksharaErrorState(
        message: 'Unable to load principal summary.',
        onRetry: () => invalidateIntelligenceReads(ref),
      ),
      data: (summary) => ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Text(summary.headline, style: context.aksharaText.displaySmall),
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Highlights'),
          for (final item in summary.highlights)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(item),
            ),
          const AksharaSectionHeader(title: 'Risks'),
          for (final item in summary.risks)
            ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(item),
            ),
          recommendationsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AksharaSectionHeader(title: 'Read-only recommendations'),
                for (final item in items)
                  Card(
                    child: ListTile(
                      title: Text(item.title),
                      subtitle: Text(item.detail),
                    ),
                  ),
              ],
            ),
          ),
          briefingAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (briefing) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AksharaSpacing.s6),
                AksharaSectionHeader(
                    title: 'Weekly briefing · ${briefing.weekLabel}'),
                for (final section in briefing.sections) ...[
                  Text(section.title,
                      style: Theme.of(context).textTheme.titleSmall),
                  for (final bullet in section.bullets)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.fiber_manual_record, size: 8),
                      title: Text(bullet),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return SizedBox(
      width: 168,
      child: Material(
        color: colors.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.kpiLabel.copyWith(color: colors.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                value,
                style: text.kpiValue.copyWith(color: colors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconForRisk(IntelligenceRiskLevel level) => switch (level) {
      IntelligenceRiskLevel.high => Icons.warning_amber,
      IntelligenceRiskLevel.medium => Icons.info_outline,
      IntelligenceRiskLevel.low => Icons.check_circle_outline,
    };

Color _colorForRisk(IntelligenceRiskLevel level) => switch (level) {
      IntelligenceRiskLevel.high => Colors.red,
      IntelligenceRiskLevel.medium => Colors.orange,
      IntelligenceRiskLevel.low => Colors.green,
    };

String _seriesTitle(String key) => switch (key) {
      'schoolHealth' => 'School health',
      'studentRisk' => 'Student risk',
      'feeCollection' => 'Fee collection health',
      _ => key,
    };
