import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../integration/sis_admissions_integration_provider.dart';
import '../sis_async_state.dart';
import '../sis_models.dart';
import '../widgets/sis_distribution_panel.dart';
import '../widgets/sis_enrollment_queue.dart';
import '../widgets/sis_kpi_row.dart';
import '../widgets/sis_module_scaffold.dart';
import 'sis_dashboard_provider.dart';
import 'widgets/sis_recent_enrollments_table.dart';

/// SIS-01 — Student Dashboard.
class SisDashboardScreen extends ConsumerWidget {
  const SisDashboardScreen({super.key});

  static const List<String> filterLabels = [
    '2026–27',
    'All classes',
    'All statuses',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(sisDashboardViewStateProvider);
    final filterIndex = ref.watch(sisDashboardFilterProvider);
    final conversionQueue = ref.watch(sisPendingEnrollmentsProvider);

    return SisModuleScaffold(
      screen: SisScreen.dashboard,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(sisDashboardFilterProvider.notifier).state = index,
      body: SisAsyncBody<SisDashboardData>(
        state: viewState,
        loadingLabel: 'Loading student SIS dashboard',
        emptyMessage: 'No student data for the selected filters.',
        emptyIcon: Icons.school_outlined,
        onRetry: () => retrySisFuture(ref, sisDashboardFutureProvider),
        builder: (data) => _buildDashboardContent(
          context,
          data: data,
          conversionQueue: conversionQueue,
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context, {
    required SisDashboardData data,
    required List<SisEnrollmentQueueItem> conversionQueue,
  }) {
    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SisKpiRow(kpis: data.kpis),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          SisDistributionPanel(
            title: 'Class distribution',
            segments: data.classDistribution,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          SisDistributionPanel(
            title: 'Gender distribution',
            segments: data.genderDistribution,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          const AksharaSectionHeader(title: 'Recent enrollments'),
          const SizedBox(height: AksharaSpacing.s3),
          SisRecentEnrollmentsTable(enrollments: data.recentEnrollments),
          const SizedBox(height: AksharaSpacing.s6),
          const AksharaSectionHeader(title: 'Admissions conversion queue'),
          const SizedBox(height: AksharaSpacing.s3),
          SisEnrollmentQueue(items: conversionQueue, compact: true),
          const SizedBox(height: AksharaSpacing.s6),
          AksharaInsightCard(
            message: data.aiInsight,
            actionLabel: 'Open conversion',
            semanticLabelPrefix: 'AI SIS insight',
            onAction: null,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SisDistributionPanel(
                            title: 'Class distribution',
                            segments: data.classDistribution,
                            height: 200,
                          ),
                        ),
                        const SizedBox(width: AksharaSpacing.s4),
                        Expanded(
                          child: SisDistributionPanel(
                            title: 'Gender distribution',
                            segments: data.genderDistribution,
                            height: 200,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AksharaSpacing.s6),
                    const AksharaSectionHeader(title: 'Recent enrollments'),
                    const SizedBox(height: AksharaSpacing.s3),
                    SisRecentEnrollmentsTable(
                      enrollments: data.recentEnrollments,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AksharaSectionHeader(
                      title: 'Admissions conversion queue',
                    ),
                    const SizedBox(height: AksharaSpacing.s3),
                    SisEnrollmentQueue(items: conversionQueue, compact: true),
                    const SizedBox(height: AksharaSpacing.s6),
                    AksharaInsightCard(
                      message: data.aiInsight,
                      actionLabel: 'Open conversion',
                      semanticLabelPrefix: 'AI SIS insight',
                      onAction: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
