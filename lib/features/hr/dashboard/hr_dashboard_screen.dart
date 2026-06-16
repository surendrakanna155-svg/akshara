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
import '../hr_models.dart';
import '../hr_providers.dart';
import '../widgets/hr_kpi_row.dart';
import '../widgets/hr_module_scaffold.dart';
import '../widgets/hr_trend_chart.dart';

/// HR-01 — HR Dashboard.
class HrDashboardScreen extends ConsumerWidget {
  const HrDashboardScreen({super.key});

  static const List<String> filterLabels = [
    'All departments',
    'Academics',
    'Administration',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(hrDashboardViewStateProvider);
    final filterIndex = ref.watch(hrDashboardFilterProvider);

    return HrModuleScaffold(
      screen: HrScreen.dashboard,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hrDashboardFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageHr,
        child: OutlinedButton.icon(
          onPressed: () => context.go(RouteNames.hrReports),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export'),
        ),
      ),
      body: ErpAsyncBody<HrDashboardData>(
        state: viewState,
        loadingLabel: 'Loading HR dashboard',
        emptyMessage: 'No HR data for the selected department.',
        emptyIcon: Icons.groups_outlined,
        onRetry: () => retryErpFuture(ref, hrDashboardFutureProvider),
        builder: (data) => _buildDashboardContent(context, data),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, HrDashboardData data) {
    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 280.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HrKpiRow(kpis: data.kpis, desktopColumns: 3),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          HrTrendChart(
            title: 'Headcount trend',
            points: data.headcountTrend,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          HrTrendChart(
            title: 'Attendance % (MTD)',
            points: data.attendanceTrend,
            height: chartHeight,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: HrTrendChart(
                  title: 'Headcount trend',
                  points: data.headcountTrend,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: HrTrendChart(
                  title: 'Attendance % (MTD)',
                  points: data.attendanceTrend,
                  height: chartHeight,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Pending leave queue'),
        const SizedBox(height: AksharaSpacing.s3),
        _PendingLeaveList(items: data.pendingLeave),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Recruitment snapshot'),
        const SizedBox(height: AksharaSpacing.s3),
        _RecruitmentSnapshot(candidates: data.recruitmentSnapshot),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'View employees',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI HR insight',
          onAction: () => context.go(RouteNames.hrEmployees),
        ),
        const SizedBox(height: AksharaSpacing.s4),
        Text(
          data.managementKpiNote,
          style: context.aksharaText.bodySmall.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PendingLeaveList extends StatelessWidget {
  const _PendingLeaveList({required this.items});

  final List<HrPendingLeaveItem> items;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Pending leave queue, ${items.length} requests',
      child: Card(
        elevation: 0,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              ListTile(
                title: Text(items[i].employeeName, style: text.titleSmall),
                subtitle: Text(
                  '${items[i].leaveType.name} · ${items[i].days} day(s) · ${items[i].submittedOn}',
                  style: text.bodySmall,
                ),
                trailing: const AksharaStatusChip(
                  label: 'Pending',
                  tone: KpiAccent.warning,
                ),
                onTap: () => context.go(RouteNames.hrLeave),
              ),
              if (i < items.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecruitmentSnapshot extends StatelessWidget {
  const _RecruitmentSnapshot({required this.candidates});

  final List<HrCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Recruitment snapshot, ${candidates.length} candidates',
      child: Card(
        elevation: 0,
        child: Column(
          children: [
            for (var i = 0; i < candidates.length; i++) ...[
              ListTile(
                title: Text(candidates[i].name, style: text.titleSmall),
                subtitle: Text(
                  '${candidates[i].role} · ${candidates[i].stage.name}',
                  style: text.bodySmall,
                ),
                onTap: () => context.go(RouteNames.hrRecruitment),
              ),
              if (i < candidates.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}
