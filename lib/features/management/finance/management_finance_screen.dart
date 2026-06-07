import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_warning_banner.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../management_models.dart';
import '../management_providers.dart';
import '../widgets/management_kpi_row.dart';
import '../widgets/management_module_scaffold.dart';
import '../widgets/management_trend_chart.dart';

/// MG-04 — Financial Health (read-only executive view).
class ManagementFinanceScreen extends ConsumerWidget {
  const ManagementFinanceScreen({super.key});

  static const List<String> filterLabels = [
    'FY 2026-27',
    'This quarter',
    'All campuses',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(managementFinanceLoadingProvider);
    final isError = ref.watch(managementFinanceErrorProvider);
    final isEmpty = ref.watch(managementFinanceEmptyProvider);
    final data = ref.watch(managementFinancialHealthProvider);
    final filterIndex = ref.watch(managementFinanceFilterProvider);

    return ManagementModuleScaffold(
      screen: ManagementScreen.finance,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(managementFinanceFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required ManagementFinancialHealthData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading financial health',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load financial health.',
      );
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No financial data for the selected filters.',
        icon: Icons.payments_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 280.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaWarningBanner(
          message:
              'Read-only executive view. Drill to Finance module for transactions and approvals.',
          semanticLabel: 'Read-only finance banner',
        ),
        const SizedBox(height: AksharaSpacing.s4),
        _FinanceHero(
          revenue: data.revenue,
          expenses: data.expenses,
          netProfit: data.netProfit,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        ManagementKpiRow(kpis: data.kpis),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          ManagementTrendChart(
            title: 'P&L trend',
            points: data.plTrend,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          ManagementTrendChart(
            title: 'Cash flow',
            points: data.cashFlowTrend,
            height: chartHeight,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ManagementTrendChart(
                  title: 'P&L trend',
                  points: data.plTrend,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: ManagementTrendChart(
                  title: 'Cash flow',
                  points: data.cashFlowTrend,
                  height: chartHeight,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Finance module drill-down'),
        const SizedBox(height: AksharaSpacing.s3),
        _FinanceDrillLinks(links: data.drillLinks),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'Open defaulters',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI finance insight',
          onAction: () {},
        ),
      ],
    );
  }
}

class _FinanceHero extends StatelessWidget {
  const _FinanceHero({
    required this.revenue,
    required this.expenses,
    required this.netProfit,
  });

  final String revenue;
  final String expenses;
  final String netProfit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      container: true,
      label: 'Financial summary: revenue $revenue, expenses $expenses, profit $netProfit',
      child: Card(
        elevation: 0,
        color: colors.primaryContainer.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s6),
          child: AdminLayout.isMobile(context)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroMetric(label: 'Revenue', value: revenue),
                    const SizedBox(height: AksharaSpacing.s3),
                    _HeroMetric(label: 'Expenses', value: expenses),
                    const SizedBox(height: AksharaSpacing.s3),
                    _HeroMetric(
                      label: 'Net profit',
                      value: netProfit,
                      emphasized: true,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _HeroMetric(label: 'Revenue', value: revenue),
                    ),
                    Expanded(
                      child: _HeroMetric(label: 'Expenses', value: expenses),
                    ),
                    Expanded(
                      child: _HeroMetric(
                        label: 'Net profit',
                        value: netProfit,
                        emphasized: true,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelLarge.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AksharaSpacing.s1),
          Text(
            value,
            style: emphasized ? text.headlineSmall : text.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _FinanceDrillLinks extends StatelessWidget {
  const _FinanceDrillLinks({required this.links});

  final List<ManagementFinanceDrillLink> links;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final link in links) ...[
            _DrillLinkCard(link: link),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Finance drill links, ${links.length} items',
      child: Wrap(
        spacing: AksharaSpacing.s4,
        runSpacing: AksharaSpacing.s4,
        children: [
          for (final link in links)
            SizedBox(
              width: 280,
              child: _DrillLinkCard(link: link),
            ),
        ],
      ),
    );
  }
}

class _DrillLinkCard extends StatelessWidget {
  const _DrillLinkCard({required this.link});

  final ManagementFinanceDrillLink link;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: true,
      label: '${link.title}: ${link.metric}',
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: () => context.go(link.route),
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.title, style: text.titleSmall),
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  link.subtitle,
                  style: text.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AksharaSpacing.s2),
                Text(link.metric, style: text.labelLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
