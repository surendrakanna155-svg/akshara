import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';
import '../admissions_navigation.dart';
import '../widgets/admissions_chart_panel.dart';
import '../widgets/admissions_module_scaffold.dart';
import 'admissions_dashboard_provider.dart';
import 'widgets/admissions_counselor_leaderboard.dart';
import 'widgets/admissions_dashboard_kpi_row.dart';
import 'widgets/admissions_followups_table.dart';
import 'widgets/admissions_pipeline_preview.dart';

/// AD-01 — Admissions CRM Dashboard.
class AdmissionsDashboardScreen extends ConsumerWidget {
  const AdmissionsDashboardScreen({super.key});

  static const List<String> filterLabels = [
    'This month',
    'All counselors',
    'All sources',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(admissionsDashboardViewStateProvider);
    final filterIndex = ref.watch(admissionsDashboardFilterProvider);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.dashboard,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(admissionsDashboardFilterProvider.notifier).state = index,
      body: AdmissionsAsyncBody<AdmissionsDashboardData>(
        state: viewState,
        loadingLabel: 'Loading admissions dashboard',
        emptyMessage: 'No admissions data for the selected filters.',
        emptyIcon: Icons.dashboard_outlined,
        onRetry: () => retryAdmissionsFuture(
          ref,
          admissionsDashboardFutureProvider,
        ),
        builder: (data) => _buildDashboardContent(context, data),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    AdmissionsDashboardData data,
  ) {
    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 296.0 : 320.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdmissionsDashboardKpiRow(kpis: data.kpis),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Pipeline preview'),
        const SizedBox(height: AksharaSpacing.s3),
        AdmissionsPipelinePreview(pipeline: data.pipeline),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          AdmissionsChartPanel(
            title: 'Conversion funnel',
            segments: data.funnelSegments,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          AdmissionsChartPanel(
            title: 'Lead sources',
            segments: data.sourceSegments,
            height: chartHeight,
            chartType: AdmissionsChartType.donut,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AdmissionsChartPanel(
                  title: 'Conversion funnel',
                  segments: data.funnelSegments,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s4),
              Expanded(
                child: AdmissionsChartPanel(
                  title: 'Lead sources',
                  segments: data.sourceSegments,
                  height: chartHeight,
                  chartType: AdmissionsChartType.donut,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Follow-ups due today'),
        const SizedBox(height: AksharaSpacing.s3),
        AdmissionsFollowupsTable(
          followUps: data.followUps,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Counselor leaderboard'),
        const SizedBox(height: AksharaSpacing.s3),
        AdmissionsCounselorLeaderboard(entries: data.leaderboard),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: data.aiActionLabel,
          onAction: null,
          semanticLabelPrefix: 'Admissions AI insight',
        ),
      ],
    );
  }
}
