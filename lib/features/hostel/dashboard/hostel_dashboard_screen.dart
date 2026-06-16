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
import '../hostel_models.dart';
import '../hostel_providers.dart';
import '../widgets/hostel_kpi_row.dart';
import '../widgets/hostel_module_scaffold.dart';

/// HO-01 — Hostel Dashboard.
class HostelDashboardScreen extends ConsumerWidget {
  const HostelDashboardScreen({super.key});

  static const List<String> filterLabels = [
    'Block A',
    'Block B',
    'All blocks',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(hostelDashboardViewStateProvider);
    final filterIndex = ref.watch(hostelDashboardFilterProvider);

    return HostelModuleScaffold(
      screen: HostelScreen.dashboard,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hostelDashboardFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageHostel,
        child: OutlinedButton.icon(
          onPressed: () => showAksharaReportExportPreviewSnackBar(context, reportName: 'Hostel dashboard'),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export'),
        ),
      ),
      body: ErpAsyncBody<HostelDashboardData>(
        state: viewState,
        loadingLabel: 'Loading hostel dashboard',
        emptyMessage: 'No hostel data for the selected block.',
        emptyIcon: Icons.hotel_outlined,
        onRetry: () => retryErpFuture(ref, hostelDashboardFutureProvider),
        builder: (data) => _buildDashboardContent(context, data),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, HostelDashboardData data) {
    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.missingStudents.isNotEmpty)
          AksharaWarningBanner(
            message: data.missingStudents.first,
            actionLabel: 'View attendance',
            onAction: () => context.go(RouteNames.hostelAttendance),
          ),
        if (data.missingStudents.isNotEmpty)
          const SizedBox(height: AksharaSpacing.s4),
        HostelKpiRow(kpis: data.kpis, desktopColumns: 3),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          _BlockOccupancyList(items: data.blockOccupancy),
          const SizedBox(height: AksharaSpacing.s4),
          _SessionAttendanceList(items: data.sessionAttendance),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _BlockOccupancyList(items: data.blockOccupancy)),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: _SessionAttendanceList(items: data.sessionAttendance),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Health alerts'),
        const SizedBox(height: AksharaSpacing.s3),
        _HealthAlertsList(alerts: data.healthAlerts),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'View students',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI hostel insight',
          onAction: () => context.go(RouteNames.sisStudents),
        ),
      ],
    );
  }
}

class _BlockOccupancyList extends StatelessWidget {
  const _BlockOccupancyList({required this.items});

  final List<HostelBlockOccupancy> items;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Semantics(
      container: true,
      label: 'Block occupancy, ${items.length} blocks',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AksharaSectionHeader(title: 'Block occupancy'),
              const SizedBox(height: AksharaSpacing.s3),
              for (final item in items) ...[
                Row(
                  children: [
                    Expanded(child: Text(item.block, style: text.bodyMedium)),
                    Text('${item.percent}%', style: text.titleSmall),
                  ],
                ),
                Text(
                  '${item.occupied} / ${item.total} beds',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AksharaSpacing.s2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.percent / 100,
                    minHeight: 8,
                    backgroundColor: colors.surfaceContainerHighest,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionAttendanceList extends StatelessWidget {
  const _SessionAttendanceList({required this.items});

  final List<HostelSessionAttendance> items;

  String _sessionLabel(HostelAttendanceSession session) => switch (session) {
        HostelAttendanceSession.morning => 'Morning',
        HostelAttendanceSession.evening => 'Evening',
        HostelAttendanceSession.night => 'Night',
      };

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Session attendance, ${items.length} sessions',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AksharaSectionHeader(title: 'Attendance by session'),
              const SizedBox(height: AksharaSpacing.s3),
              for (final item in items) ...[
                Text(_sessionLabel(item.session), style: text.titleSmall),
                Text(
                  'Present ${item.present} · Absent ${item.absent} · Leave ${item.onLeave}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthAlertsList extends StatelessWidget {
  const _HealthAlertsList({required this.alerts});

  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final alert in alerts)
              Text('• $alert', style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}
