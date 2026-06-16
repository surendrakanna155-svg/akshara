import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../control_center/intelligence/platform_intelligence_models.dart';
import '../control_center/intelligence/platform_intelligence_providers.dart';
import 'trust_intelligence_providers.dart';

class TrustIntelligenceHubScreen extends ConsumerStatefulWidget {
  const TrustIntelligenceHubScreen({super.key});

  @override
  ConsumerState<TrustIntelligenceHubScreen> createState() =>
      _TrustIntelligenceHubScreenState();
}

class _TrustIntelligenceHubScreenState
    extends ConsumerState<TrustIntelligenceHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 7,
      vsync: this,
      animationDuration: Duration.zero,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(trustIntelligenceCanViewProvider)) {
      return const Scaffold(
        body: Center(
            child: Text('Organization intelligence permission required.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Trust Intelligence'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Trust'),
            Tab(text: 'Comparison'),
            Tab(text: 'Revenue'),
            Tab(text: 'Growth'),
            Tab(text: 'Risk'),
            Tab(text: 'Recommendations'),
            Tab(text: 'Executive Summary'),
          ],
        ),
      ),
      body: SizedBox(
        key: QaTestKeys.trustIntelligenceScreen,
        child: TabBarView(
          controller: _tabs,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _trustTab(ref),
            _comparisonTab(ref),
            _revenueTab(ref),
            _growthTab(ref),
            _riskTab(ref),
            _recommendationsTab(ref),
            _summaryTab(ref),
          ],
        ),
      ),
    );
  }

  Widget _trustTab(WidgetRef ref) {
    final trust = ref.watch(trustDashboardProvider);
    return trust.when(
      data: (value) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(value.trustName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _kpiWrap(value.kpis),
          const Divider(),
          ...value.trend.map(
            (point) => ListTile(
              title: Text(point.label),
              trailing: Text(point.value.toStringAsFixed(0)),
            ),
          ),
          const Divider(),
          ...value.riskHighlights.map(
            (item) =>
                ListTile(title: Text(item.title), subtitle: Text(item.detail)),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _comparisonTab(WidgetRef ref) {
    final comparison = ref.watch(schoolComparisonIntelligenceProvider);
    return comparison.when(
      data: (value) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DataTable(
            columns: const [
              DataColumn(label: Text('School')),
              DataColumn(label: Text('Students')),
              DataColumn(label: Text('Revenue')),
              DataColumn(label: Text('Growth')),
              DataColumn(label: Text('Risk')),
            ],
            rows: [
              for (final row in value.rows)
                DataRow(
                  cells: [
                    DataCell(Text(row.schoolName)),
                    DataCell(Text('${row.studentCount}')),
                    DataCell(
                        Text('INR ${row.revenueLakhs.toStringAsFixed(1)}L')),
                    DataCell(Text('${row.growthPercent}%')),
                    DataCell(Text('${row.riskScore}')),
                  ],
                ),
            ],
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _revenueTab(WidgetRef ref) {
    final revenue = ref.watch(revenueIntelligenceProvider);
    return revenue.when(
      data: (value) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _kpiWrap(value.kpis),
          const Divider(),
          ...value.revenueTrend.map(
            (point) => ListTile(
              title: Text(point.label),
              subtitle: Text('INR ${point.value.toStringAsFixed(1)}L'),
              trailing: Text(point.target == null
                  ? '—'
                  : 'Target ${point.target!.toStringAsFixed(1)}L'),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _growthTab(WidgetRef ref) {
    final growth = ref.watch(growthIntelligenceProvider);
    return growth.when(
      data: (value) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _kpiWrap(value.kpis),
          const Divider(),
          ...value.pipeline.map(
            (item) => ListTile(
              title: Text(item.name),
              subtitle: Text('${item.stage} · ${item.timeline}'),
              trailing:
                  Text('INR ${item.expectedRevenueLakhs.toStringAsFixed(1)}L'),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _riskTab(WidgetRef ref) {
    final risk = ref.watch(portfolioRiskIntelligenceProvider);
    return risk.when(
      data: (value) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _kpiWrap(value.kpis),
          const Divider(),
          ...value.risks.map(
            (row) => ListTile(
              title: Text('${row.schoolName} · ${row.riskType}'),
              subtitle: Text(row.mitigation),
              trailing: Text('Score ${row.riskScore}'),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _recommendationsTab(WidgetRef ref) {
    final recommendations = ref.watch(trustRecommendationsProvider);
    return recommendations.when(
      data: (items) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            child: ListTile(
              title: Text(item.title),
              subtitle: Text(item.detail),
              trailing: Text('${item.owner}\n${item.priority.toUpperCase()}'),
              isThreeLine: true,
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _summaryTab(WidgetRef ref) {
    final summary = ref.watch(trustExecutiveSummaryProvider);
    return summary.when(
      data: (value) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(value.headline, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(value.summary),
          const Divider(),
          ...value.priorityActions.map(
            (item) => ListTile(
              title: Text(item.title),
              subtitle: Text(item.detail),
              trailing: Text(item.priority.toUpperCase()),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _kpiWrap(List<PlatformIntelligenceKpi> kpis) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final kpi in kpis)
          SizedBox(
            width: 260,
            child: Card(
              child: ListTile(
                title: Text(kpi.label),
                subtitle: Text(kpi.delta ?? ''),
                trailing: Text(kpi.value),
              ),
            ),
          ),
      ],
    );
  }
}
