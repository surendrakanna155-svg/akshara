import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/permissions.dart';
import '../../../router/route_names.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../alumni_models.dart';
import '../alumni_providers.dart';
import '../widgets/alumni_kpi_row.dart';
import '../widgets/alumni_module_scaffold.dart';

/// AL-01 — Alumni Dashboard.
class AlumniDashboardScreen extends ConsumerWidget {
  const AlumniDashboardScreen({super.key});

  static const List<String> filterLabels = [
    'All batches',
    '2024–25',
    '2022–23',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(alumniDashboardViewStateProvider);
    final filterIndex = ref.watch(alumniDashboardFilterProvider);

    return AlumniModuleScaffold(
      screen: AlumniScreen.dashboard,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(alumniDashboardFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageAlumni,
        child: OutlinedButton.icon(
          onPressed: () => showAksharaReportExportPreviewSnackBar(context, reportName: 'Alumni dashboard'),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export'),
        ),
      ),
      body: ErpAsyncBody<AlumniDashboardData>(
        state: viewState,
        loadingLabel: 'Loading alumni dashboard',
        emptyMessage: 'No alumni data for the selected batch.',
        emptyIcon: Icons.school_outlined,
        onRetry: () => retryErpFuture(ref, alumniDashboardFutureProvider),
        builder: (data) => _buildDashboardContent(context, data),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    AlumniDashboardData data,
  ) {
    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlumniKpiRow(kpis: data.kpis, desktopColumns: 3),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Recent SIS graduates'),
        const SizedBox(height: AksharaSpacing.s3),
        _GraduatesList(graduates: data.recentGraduates),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          _DonationSummaryCard(summary: data.donationSummary),
          const SizedBox(height: AksharaSpacing.s4),
          _EngagementCard(metrics: data.engagement),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _DonationSummaryCard(summary: data.donationSummary)),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(child: _EngagementCard(metrics: data.engagement)),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'View SIS graduates',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI alumni insight',
          onAction: () => context.go(RouteNames.sisStudents),
        ),
      ],
    );
  }
}

class _GraduatesList extends StatelessWidget {
  const _GraduatesList({required this.graduates});

  final List<AlumniRecord> graduates;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Recent graduates, ${graduates.length} alumni',
      child: Column(
        children: [
          for (final alumni in graduates) ...[
            Card(
              elevation: 0,
              child: ListTile(
                title: Text(alumni.name, style: text.titleSmall),
                subtitle: Text(
                  'Batch ${alumni.batchYear} · ${alumni.sisStudentId} · ${alumni.currentRole}',
                  style: text.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(RouteNames.alumniProfileDetail(alumni.id)),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s2),
          ],
        ],
      ),
    );
  }
}

class _DonationSummaryCard extends StatelessWidget {
  const _DonationSummaryCard({required this.summary});

  final AlumniDonationSummary summary;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Semantics(
      container: true,
      label: 'Donations received ${summary.totalReceived}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AksharaSectionHeader(title: 'Donation summary'),
              const SizedBox(height: AksharaSpacing.s3),
              Text(summary.totalReceived, style: text.headlineSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                'Pledged ${summary.pledgedAmount} · Pending ${summary.pendingAmount}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              TextButton(
                onPressed: () => context.go(RouteNames.financeCollections),
                child: const Text('View Finance ledger (FN-05)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EngagementCard extends StatelessWidget {
  const _EngagementCard({required this.metrics});

  final AlumniEngagementMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Engagement metrics',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AksharaSectionHeader(title: 'Engagement'),
              const SizedBox(height: AksharaSpacing.s3),
              Text('${metrics.activeAlumni} active alumni', style: text.titleMedium),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                'Event attendance ${metrics.eventAttendanceRate} · '
                '${metrics.mentorshipPairs} mentorship pairs · '
                '${metrics.campaignParticipation} campaign participation',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
