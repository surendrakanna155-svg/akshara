import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/permissions.dart';
import '../../../core/school_config/school_configuration_provider.dart';
import '../../../core/school_config/school_dashboard_adapter.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../../copilot/copilot_context_provider.dart';
import '../../copilot/copilot_screen_context.dart';
import '../management_models.dart';
import '../management_mutations_provider.dart';
import '../management_providers.dart';
import '../widgets/management_kpi_row.dart';
import '../widgets/management_principal_overview_panel.dart';
import '../widgets/management_module_scaffold.dart';
import '../widgets/management_segment_panel.dart';
import '../widgets/management_trend_chart.dart';
import '../attendance/office_attendance_screen.dart';

/// MG-01 — Management Dashboard.
class ManagementDashboardScreen extends ConsumerWidget {
  const ManagementDashboardScreen({super.key});

  static const List<String> filterLabels = [
    'FY 2026-27',
    'Q1',
    'All quarters',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(managementDashboardViewStateProvider);
    final filterIndex = ref.watch(managementDashboardFilterProvider);

    return ManagementModuleScaffold(
      screen: ManagementScreen.dashboard,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(managementDashboardFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageManagement,
        child: OutlinedButton.icon(
          key: QaTestKeys.managementDashboardExportButton,
          onPressed: () async {
            final bytes = await ref
                .read(exportManagementDashboardProvider.notifier)
                .execute();
            if (!context.mounted || bytes == null) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                key: QaTestKeys.managementDashboardExportSuccessSnackbar,
                content: Text('Management dashboard PDF generated'),
              ),
            );
            await showModalBottomSheet<void>(
              context: context,
              builder: (sheetContext) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AksharaSpacing.s4),
                    child: Wrap(
                      runSpacing: AksharaSpacing.s3,
                      children: [
                        ListTile(
                          key: QaTestKeys.managementDashboardPrintButton,
                          leading: const Icon(Icons.print_outlined),
                          title: const Text('Print dashboard PDF'),
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await ref
                                .read(managementDashboardPdfServiceProvider)
                                .printDashboard(bytes);
                          },
                        ),
                        ListTile(
                          key: QaTestKeys.managementDashboardShareButton,
                          leading: const Icon(Icons.share_outlined),
                          title: const Text('Share dashboard PDF'),
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await ref
                                .read(managementDashboardPdfServiceProvider)
                                .shareDashboard(
                                  bytes: bytes,
                                  fileName: 'management_dashboard.pdf',
                                );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export'),
        ),
      ),
      body: ErpAsyncBody<ManagementDashboardData>(
        state: viewState,
        loadingLabel: 'Loading management dashboard',
        emptyMessage: 'No management data for the selected filters.',
        emptyIcon: Icons.dashboard_outlined,
        onRetry: () => retryErpFuture(ref, managementDashboardFutureProvider),
        skeleton: AksharaSkeleton.dashboard(),
        builder: (data) =>
            _buildDashboardContent(context, ref, data, filterIndex),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    ManagementDashboardData data,
    int filterIndex,
  ) {
    final configured = adaptManagementDashboard(
      data,
      ref.watch(schoolCapabilitiesProvider),
    );
    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 300.0;
    final queuePreview = configured.approvalQueue.take(5).toList();

    return CopilotContextScope(
      route: RouteNames.managementDashboard,
      screen: 'Owner Dashboard',
      module: 'management',
      filters: {'period': filterLabels[filterIndex]},
      kpis: [
        for (final kpi in configured.kpis)
          CopilotKpiSnapshot(id: kpi.id, label: kpi.label, value: kpi.value),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManagementPrincipalOverviewPanel(data: configured),
          if (configured.feeSnapshot.defaulters > 40)
            AksharaWarningBanner(
              message:
                  '${configured.feeSnapshot.defaulters} fee defaulters with ${configured.feeSnapshot.outstanding} outstanding.',
              actionLabel: 'View defaulters',
              onAction: () => context.go(RouteNames.financeDefaulters),
            ),
          if (configured.feeSnapshot.defaulters > 40)
            const SizedBox(height: AksharaSpacing.s4),
          ManagementKpiRow(
            desktopColumns: 3,
            kpis: configured.kpis,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          if (isMobile) ...[
            ManagementTrendChart(
              title: 'Revenue trend',
              points: data.revenueTrend,
              height: chartHeight,
            ),
            const SizedBox(height: AksharaSpacing.s6),
            ManagementSegmentPanel(
              title: 'Expense breakdown',
              segments: data.expenseBreakdown,
              height: chartHeight,
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ManagementTrendChart(
                    title: 'Revenue trend',
                    points: data.revenueTrend,
                    height: chartHeight,
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s6),
                Expanded(
                  flex: 2,
                  child: ManagementSegmentPanel(
                    title: 'Expense breakdown',
                    segments: data.expenseBreakdown,
                    height: chartHeight,
                  ),
                ),
              ],
            ),
          const SizedBox(height: AksharaSpacing.s6),
          AksharaSectionHeader(
            title: 'Attendance oversight',
            trailingLabel: 'Open workspace',
            onTrailingTap: () =>
                context.go(RouteNames.managementOfficeAttendance),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          const _AttendancePendingWidget(),
          const SizedBox(height: AksharaSpacing.s6),
          const AksharaSectionHeader(title: 'Approval queue'),
          const SizedBox(height: AksharaSpacing.s3),
          _ApprovalQueuePreview(items: queuePreview),
          const SizedBox(height: AksharaSpacing.s6),
          if (isMobile) ...[
            _AdmissionsSnapshotCard(snapshot: data.admissionsSnapshot),
            const SizedBox(height: AksharaSpacing.s4),
            _FeeSnapshotCard(snapshot: data.feeSnapshot),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _AdmissionsSnapshotCard(
                    snapshot: data.admissionsSnapshot,
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s6),
                Expanded(
                  child: _FeeSnapshotCard(snapshot: data.feeSnapshot),
                ),
              ],
            ),
          const SizedBox(height: AksharaSpacing.s6),
          AksharaInsightCard(
            message: data.aiInsight,
            actionLabel: 'View approvals',
            icon: Icons.auto_awesome_outlined,
            semanticLabelPrefix: 'AI management insight',
            onAction: () => context.go(RouteNames.managementApprovals),
          ),
        ],
      ),
    );
  }
}

/// ATT-4 — a small "Attendance pending" dashboard widget. Reads the same
/// office-attendance pending feed (today's classes with no submitted session)
/// and links into the office attendance workspace. Read-only.
class _AttendancePendingWidget extends ConsumerWidget {
  const _AttendancePendingWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(officePendingProvider);
    return Card(
      child: InkWell(
        onTap: () => context.go(RouteNames.managementOfficeAttendance),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: async.when(
            loading: () => const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AksharaSpacing.s3),
                Text('Checking attendance…'),
              ],
            ),
            error: (_, __) => Row(
              children: [
                Icon(Icons.error_outline, color: context.colors.error),
                const SizedBox(width: AksharaSpacing.s3),
                const Expanded(child: Text('Attendance status unavailable')),
              ],
            ),
            data: (rows) {
              final ok = rows.isEmpty;
              return Row(
                children: [
                  Icon(
                    ok ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                    color: ok ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  Expanded(
                    child: Text(
                      ok
                          ? 'All classes have submitted attendance today.'
                          : '${rows.length} ${rows.length == 1 ? 'class has' : 'classes have'} not submitted attendance today.',
                      style: context.aksharaText.bodyMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ApprovalQueuePreview extends StatelessWidget {
  const _ApprovalQueuePreview({required this.items});

  final List<ManagementApprovalItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Semantics(
        label: 'No pending approvals',
        child: Text(
          'No items in the approval queue.',
          style: context.aksharaText.bodyMedium.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final item in items) ...[
            _ApprovalQueueCard(item: item),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Approval queue preview, ${items.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Requester')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  onSelectChanged: (_) =>
                      context.go(RouteNames.managementApprovals),
                  cells: [
                    DataCell(Text(item.title)),
                    DataCell(Text(item.requester)),
                    DataCell(Text(item.amount)),
                    DataCell(Text(item.dateLabel)),
                    DataCell(_ApprovalStatusChip(status: item.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApprovalQueueCard extends StatelessWidget {
  const _ApprovalQueueCard({required this.item});

  final ManagementApprovalItem item;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Approval: ${item.title}, ${item.amount}',
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: () => context.go(RouteNames.managementApprovals),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: text.titleSmall),
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  '${item.requester} · ${item.amount} · ${item.dateLabel}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AksharaSpacing.s2),
                _ApprovalStatusChip(status: item.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApprovalStatusChip extends StatelessWidget {
  const _ApprovalStatusChip({required this.status});

  final ManagementApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      ManagementApprovalStatus.pending => ('Pending', KpiAccent.warning),
      ManagementApprovalStatus.approved => ('Approved', KpiAccent.success),
      ManagementApprovalStatus.rejected => ('Rejected', KpiAccent.error),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _AdmissionsSnapshotCard extends StatelessWidget {
  const _AdmissionsSnapshotCard({required this.snapshot});

  final ManagementAdmissionsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label:
          'Admissions snapshot: ${snapshot.leadsMtd} leads, ${snapshot.joined} joined',
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admissions snapshot', style: text.titleMedium),
              const SizedBox(height: AksharaSpacing.s4),
              _SnapshotMetric(
                label: 'Leads (MTD)',
                value: '${snapshot.leadsMtd}',
              ),
              _SnapshotMetric(
                label: 'Confirmed',
                value: '${snapshot.confirmed}',
              ),
              _SnapshotMetric(
                label: 'Joined',
                value: '${snapshot.joined}',
              ),
              _SnapshotMetric(
                label: 'Conversion rate',
                value: snapshot.conversionRate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeeSnapshotCard extends StatelessWidget {
  const _FeeSnapshotCard({required this.snapshot});

  final ManagementFeeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label:
          'Fee snapshot: ${snapshot.collectionRate} collected, ${snapshot.defaulters} defaulters',
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fee collection', style: text.titleMedium),
              const SizedBox(height: AksharaSpacing.s4),
              _SnapshotMetric(
                label: 'Collected (MTD)',
                value: snapshot.collectedMtd,
              ),
              _SnapshotMetric(
                label: 'Outstanding',
                value: snapshot.outstanding,
              ),
              _SnapshotMetric(
                label: 'Collection rate',
                value: snapshot.collectionRate,
              ),
              _SnapshotMetric(
                label: 'Defaulters',
                value: '${snapshot.defaulters}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapshotMetric extends StatelessWidget {
  const _SnapshotMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyMedium)),
          Text(value, style: text.titleSmall),
        ],
      ),
    );
  }
}
