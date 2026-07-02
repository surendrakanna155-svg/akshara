import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../library_models.dart';
import '../library_providers.dart';
import '../library_workflow_actions.dart';
import '../widgets/library_kpi_row.dart';
import '../widgets/library_module_scaffold.dart';
import '../widgets/library_segment_panel.dart';
import '../widgets/library_trend_chart.dart';

/// LB-01 — Library Dashboard.
class LibraryDashboardScreen extends ConsumerWidget {
  const LibraryDashboardScreen({super.key});

  static const List<String> filterLabels = [
    'This week',
    'This month',
    'All time',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(libraryDashboardViewStateProvider);
    final filterIndex = ref.watch(libraryDashboardFilterProvider);

    return LibraryModuleScaffold(
      screen: LibraryScreen.dashboard,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(libraryDashboardFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageLibrary,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: QaTestKeys.librarySettingsButton,
              onPressed: () => showLibrarySettingsDialog(context, ref),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Library settings',
            ),
            const SizedBox(width: AksharaSpacing.s2),
            FilledButton.icon(
              key: QaTestKeys.libraryIssueScanButton,
              onPressed: () => showIssueLibraryBookDialog(context, ref),
              icon: const Icon(Icons.qr_code_scanner_outlined, size: 18),
              label: const Text('Issue book'),
            ),
          ],
        ),
      ),
      body: ErpAsyncBody<LibraryDashboardData>(
        state: viewState,
        loadingLabel: 'Loading library dashboard',
        emptyMessage: 'No library data for the selected period.',
        emptyIcon: Icons.menu_book_outlined,
        onRetry: () => retryErpFuture(ref, libraryDashboardFutureProvider),
        builder: (data) => _buildDashboardContent(context, data),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    LibraryDashboardData data,
  ) {
    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 300.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.overdueTitles.isNotEmpty)
          AksharaWarningBanner(
            message: data.overdueTitles.first,
            actionLabel: 'View overdue',
            onAction: () => context.go(RouteNames.libraryOverdue),
          ),
        if (data.overdueTitles.isNotEmpty)
          const SizedBox(height: AksharaSpacing.s4),
        LibraryKpiRow(kpis: data.kpis, desktopColumns: 3),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Recent issues'),
        const SizedBox(height: AksharaSpacing.s3),
        _RecentIssuesTable(issues: data.recentIssues),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          LibraryTrendChart(
            title: 'Issue trend (monthly)',
            points: data.issueTrend,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          LibrarySegmentPanel(
            title: 'Category distribution',
            segments: data.categoryDistribution,
            height: chartHeight,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: LibraryTrendChart(
                  title: 'Issue trend (monthly)',
                  points: data.issueTrend,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                flex: 2,
                child: LibrarySegmentPanel(
                  title: 'Category distribution',
                  segments: data.categoryDistribution,
                  height: chartHeight,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'View fines',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI library insight',
          onAction: () => context.go(RouteNames.libraryFines),
        ),
      ],
    );
  }
}

class _RecentIssuesTable extends StatelessWidget {
  const _RecentIssuesTable({required this.issues});

  final List<LibraryIssueRecord> issues;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final issue in issues) ...[
            _IssueCard(issue: issue),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Recent issues table, ${issues.length} loans',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Member')),
              DataColumn(label: Text('Book')),
              DataColumn(label: Text('Issued')),
              DataColumn(label: Text('Due')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final issue in issues)
                DataRow(
                  cells: [
                    DataCell(Text(issue.memberName)),
                    DataCell(Text(issue.bookTitle)),
                    DataCell(Text(issue.issuedDate)),
                    DataCell(Text(issue.dueDate)),
                    DataCell(_LoanStatusChip(status: issue.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});

  final LibraryIssueRecord issue;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: '${issue.memberName}, ${issue.bookTitle}, due ${issue.dueDate}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(issue.memberName, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(issue.bookTitle, style: text.bodyMedium),
              Text(
                'Due ${issue.dueDate}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              _LoanStatusChip(status: issue.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoanStatusChip extends StatelessWidget {
  const _LoanStatusChip({required this.status});

  final LibraryLoanStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      LibraryLoanStatus.active => ('Active', KpiAccent.primary),
      LibraryLoanStatus.overdue => ('Overdue', KpiAccent.warning),
      LibraryLoanStatus.returned => ('Returned', KpiAccent.success),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Loan status: $label',
    );
  }
}
