import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_warning_banner.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../integration/finance_admissions_handoff_provider.dart';
import '../widgets/finance_collection_trend_chart.dart';
import '../widgets/finance_handoff_queue.dart';
import '../widgets/finance_kpi_row.dart';
import '../widgets/finance_module_scaffold.dart';
import 'finance_dashboard_provider.dart';
import 'widgets/finance_recent_payments_table.dart';

/// FN-01 — Finance Dashboard.
class FinanceDashboardScreen extends ConsumerWidget {
  const FinanceDashboardScreen({super.key});

  static const List<String> filterLabels = [
    'This month',
    'All classes',
    'All modes',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(financeDashboardViewStateProvider);
    final filterIndex = ref.watch(financeDashboardFilterProvider);
    final handoffQueue = ref.watch(financePendingHandoffsProvider);

    return FinanceModuleScaffold(
      screen: FinanceScreen.dashboard,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(financeDashboardFilterProvider.notifier).state = index,
      body: FinanceAsyncBody<FinanceDashboardData>(
        state: viewState,
        loadingLabel: 'Loading finance dashboard',
        emptyMessage: 'No finance data for the selected filters.',
        emptyIcon: Icons.account_balance_wallet_outlined,
        onRetry: () => retryFinanceFuture(ref, financeDashboardFutureProvider),
        builder: (data) => _buildDashboardContent(
          context,
          data: data,
          handoffQueue: handoffQueue,
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context, {
    required FinanceDashboardData data,
    required List<FinanceHandoffQueueItem> handoffQueue,
  }) {
    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 300.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.defaultersCount > 40)
          AksharaWarningBanner(
            message:
                '${data.defaultersCount} defaulters with outstanding ${data.outstandingAmount}. Review pending fees.',
            actionLabel: 'View defaulters',
            onAction: () {},
          ),
        if (data.defaultersCount > 40)
          const SizedBox(height: AksharaSpacing.s4),
        FinanceKpiRow(kpis: data.kpis),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          FinanceCollectionTrendChart(
            title: 'Collection trend',
            points: data.collectionTrend,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          const AksharaSectionHeader(title: 'Recent payments'),
          const SizedBox(height: AksharaSpacing.s3),
          FinanceRecentPaymentsTable(payments: data.recentPayments),
          const SizedBox(height: AksharaSpacing.s6),
          const AksharaSectionHeader(title: 'Admissions handoff queue'),
          const SizedBox(height: AksharaSpacing.s3),
          FinanceHandoffQueue(items: handoffQueue, compact: true),
          const SizedBox(height: AksharaSpacing.s6),
          AksharaInsightCard(
            message: data.aiInsight,
            actionLabel: 'Review defaulters',
            icon: Icons.auto_awesome_outlined,
            semanticLabelPrefix: 'AI finance insight',
            onAction: () {},
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
                    FinanceCollectionTrendChart(
                      title: 'Collection trend',
                      points: data.collectionTrend,
                      height: chartHeight,
                    ),
                    const SizedBox(height: AksharaSpacing.s6),
                    const AksharaSectionHeader(title: 'Recent payments'),
                    const SizedBox(height: AksharaSpacing.s3),
                    FinanceRecentPaymentsTable(payments: data.recentPayments),
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
                      title: 'Admissions handoff queue',
                    ),
                    const SizedBox(height: AksharaSpacing.s3),
                    FinanceHandoffQueue(items: handoffQueue, compact: true),
                    const SizedBox(height: AksharaSpacing.s6),
                    AksharaInsightCard(
                      message: data.aiInsight,
                      actionLabel: 'Review defaulters',
                      icon: Icons.auto_awesome_outlined,
                      semanticLabelPrefix: 'AI finance insight',
                      onAction: () {},
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
