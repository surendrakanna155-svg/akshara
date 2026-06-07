import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_warning_banner.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_kpi_row.dart';
import '../widgets/control_center_module_scaffold.dart';
import '../widgets/control_center_segment_panel.dart';
import '../widgets/control_center_trend_chart.dart';

/// ACC-01 — Platform Dashboard.
class ControlCenterDashboardScreen extends ConsumerWidget {
  const ControlCenterDashboardScreen({super.key});

  static const List<String> filterLabels = [
    'All schools',
    'Active',
    'Trial',
    'Expiring',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(controlCenterDashboardViewStateProvider);
    final filterIndex = ref.watch(controlCenterDashboardFilterProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.dashboard,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(controlCenterDashboardFilterProvider.notifier).state = index,
      filterTrailing: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.download_outlined, size: 18),
        label: const Text('Export'),
      ),
      body: ErpAsyncBody<ControlCenterDashboardData>(
        state: viewState,
        loadingLabel: 'Loading control center dashboard',
        emptyMessage: 'No platform data for the selected filters.',
        emptyIcon: Icons.hub_outlined,
        onRetry: () =>
            retryErpFuture(ref, controlCenterDashboardFutureProvider),
        builder: (data) => _buildDashboardContent(context, data),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    ControlCenterDashboardData data,
  ) {
    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.expiringSchools.isNotEmpty)
          AksharaWarningBanner(
            message: data.expiringSchools.first,
            actionLabel: 'View subscriptions',
            onAction: () => context.go(RouteNames.controlCenterSubscriptions),
          ),
        if (data.expiringSchools.isNotEmpty)
          const SizedBox(height: AksharaSpacing.s4),
        ControlCenterKpiRow(kpis: data.kpis, desktopColumns: 4),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          ControlCenterTrendChart(
            title: 'School growth',
            points: data.schoolGrowthTrend,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          ControlCenterTrendChart(
            title: 'Revenue trend (MRR)',
            points: data.revenueTrend,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ControlCenterTrendChart(
                  title: 'School growth',
                  points: data.schoolGrowthTrend,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: ControlCenterTrendChart(
                  title: 'Revenue trend (MRR)',
                  points: data.revenueTrend,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        ControlCenterSegmentPanel(
          title: 'Plan distribution',
          segments: data.planDistribution,
          height: 240,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'ERP module adoption'),
        const SizedBox(height: AksharaSpacing.s3),
        _ErpModuleGrid(modules: data.erpModules),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'View customer success',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI platform insight',
          onAction: () => context.go(RouteNames.controlCenterSuccess),
        ),
      ],
    );
  }
}

class _ErpModuleGrid extends StatelessWidget {
  const _ErpModuleGrid({required this.modules});

  final List<ErpModuleReference> modules;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'ERP module adoption, ${modules.length} modules',
      child: Wrap(
        spacing: AksharaSpacing.s3,
        runSpacing: AksharaSpacing.s3,
        children: [
          for (final module in modules)
            Semantics(
              button: true,
              label:
                  '${module.label}: ${module.adoptionPercent} percent adoption',
              child: Material(
                color: Colors.transparent,
                child: ActionChip(
                  label: Text(
                    '${module.label} · ${module.adoptionPercent}%',
                    style: text.labelMedium,
                  ),
                  onPressed: () => context.go(module.route),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
