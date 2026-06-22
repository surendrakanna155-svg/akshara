import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../admin/admin_layout.dart';
import '../../../copilot/copilot_context_provider.dart';
import '../../../copilot/copilot_screen_context.dart';
import '../control_center_models.dart';
import '../widgets/control_center_module_scaffold.dart';
import 'platform_intelligence_models.dart';
import 'platform_intelligence_providers.dart';
import '../../../../router/route_names.dart';

class PlatformIntelligenceScreen extends ConsumerStatefulWidget {
  const PlatformIntelligenceScreen({super.key});

  @override
  ConsumerState<PlatformIntelligenceScreen> createState() =>
      _PlatformIntelligenceScreenState();
}

class _PlatformIntelligenceScreenState
    extends ConsumerState<PlatformIntelligenceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(platformIntelligenceCanViewProvider)) {
      return const Scaffold(
        body: Center(
            child: Text('Control Center intelligence permission required.')),
      );
    }

    final dashboard = ref.watch(platformIntelligenceDashboardProvider);
    final revenue = ref.watch(revenueIntelligenceProvider).valueOrNull;
    final risk = ref.watch(portfolioRiskIntelligenceProvider).valueOrNull;
    final dashboardRevenue = dashboard.valueOrNull?.ownerKpis.isNotEmpty == true
        ? dashboard.valueOrNull!.ownerKpis.first.value
        : '—';
    final mrr =
        revenue?.kpis.isNotEmpty == true ? revenue!.kpis.first.value : '—';
    final riskScore =
        risk?.kpis.isNotEmpty == true ? risk!.kpis.first.value : '—';

    final kpis = [
      CopilotKpiSnapshot(
        id: 'portfolio_revenue',
        label: 'Portfolio Revenue',
        value: dashboardRevenue,
      ),
      CopilotKpiSnapshot(
        id: 'mrr',
        label: 'MRR',
        value: mrr,
      ),
      CopilotKpiSnapshot(
        id: 'portfolio_risk',
        label: 'Portfolio Risk',
        value: riskScore,
      ),
    ];

    return CopilotContextScope(
      route: RouteNames.controlCenterIntelligence,
      module: 'control_center',
      screen: 'Platform Intelligence',
      kpis: kpis,
      child: ControlCenterModuleScaffold(
        screen: ControlCenterScreen.intelligence,
        showFilterBar: false,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Platform Owner'),
                Tab(text: 'Organization'),
                Tab(text: 'School Comparison'),
                Tab(text: 'Revenue'),
                Tab(text: 'Growth'),
                Tab(text: 'Risk'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              key: QaTestKeys.platformIntelligenceScreen,
              height: 640,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _dashboardTab(ref),
                  _organizationTab(ref),
                  _comparisonTab(ref),
                  _revenueTab(ref),
                  _growthTab(ref),
                  _riskTab(ref),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardTab(WidgetRef ref) {
    final data = ref.watch(platformIntelligenceDashboardProvider);
    return data.when(
      data: (value) => ListView(
        children: [
          _kpiWrap(value.ownerKpis),
          const SizedBox(height: 12),
          _kpiWrap(value.organizationKpis),
          const SizedBox(height: 12),
          ...value.topInsights.map(
            (insight) => ListTile(
              title: Text(insight.title),
              subtitle: Text(insight.detail),
              trailing: Text(insight.priority.toUpperCase()),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _organizationTab(WidgetRef ref) {
    final data = ref.watch(organizationIntelligenceProvider);
    return data.when(
      data: (value) => ListView(
        children: [
          ListTile(
              title: const Text('Organization'),
              subtitle: Text(value.organizationName)),
          ListTile(
            title: const Text('Schools / Students'),
            subtitle: Text(
                '${value.schoolCount} schools · ${value.activeStudentCount} students'),
          ),
          ListTile(
            title: const Text('Revenue'),
            subtitle: Text('INR ${value.revenueLakhs.toStringAsFixed(1)}L'),
          ),
          ListTile(
            title: const Text('Collection Efficiency'),
            subtitle: Text('${value.collectionEfficiencyPercent}%'),
          ),
          ListTile(
              title: const Text('Health Score'),
              subtitle: Text('${value.healthScore}')),
          const Divider(),
          ...value.recommendations.map((item) => ListTile(title: Text(item))),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _comparisonTab(WidgetRef ref) {
    final data = ref.watch(schoolComparisonIntelligenceProvider);
    return data.when(
      data: (value) => ListView(
        children: [
          if (AdminLayout.useCardLayout(context))
            for (final row in value.rows) ...[
              AksharaKeyValueCard(
                title: row.schoolName,
                entries: [
                  ('Students', '${row.studentCount}'),
                  ('Revenue', 'INR ${row.revenueLakhs.toStringAsFixed(1)}L'),
                  ('Growth', '${row.growthPercent}%'),
                  ('Risk', '${row.riskScore}'),
                ],
              ),
              const SizedBox(height: 8),
            ]
          else
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
          const SizedBox(height: 12),
          ...value.benchmarks.map((insight) => ListTile(
              title: Text(insight.title), subtitle: Text(insight.detail))),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _revenueTab(WidgetRef ref) {
    final data = ref.watch(revenueIntelligenceProvider);
    return data.when(
      data: (value) => ListView(
        children: [
          _kpiWrap(value.kpis),
          const Divider(),
          ...value.revenueTrend.map(
            (point) => ListTile(
              title: Text(point.label),
              subtitle: Text('Revenue INR ${point.value.toStringAsFixed(1)}L'),
              trailing: Text(point.target == null
                  ? '—'
                  : 'Target ${point.target!.toStringAsFixed(1)}L'),
            ),
          ),
          const Divider(),
          ...value.organizationBreakdown.map(
            (kpi) =>
                ListTile(title: Text(kpi.label), trailing: Text(kpi.value)),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _growthTab(WidgetRef ref) {
    final data = ref.watch(growthIntelligenceProvider);
    return data.when(
      data: (value) => ListView(
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
          const Divider(),
          ...value.expansionSignals.map((item) =>
              ListTile(title: Text(item.title), subtitle: Text(item.detail))),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _riskTab(WidgetRef ref) {
    final data = ref.watch(portfolioRiskIntelligenceProvider);
    return data.when(
      data: (value) => ListView(
        children: [
          _kpiWrap(value.kpis),
          const Divider(),
          ...value.riskTrend.map(
            (point) => ListTile(
              title: Text(point.label),
              trailing: Text('Risk ${point.value.toStringAsFixed(0)}'),
            ),
          ),
          const Divider(),
          ...value.risks.map(
            (risk) => ListTile(
              title: Text('${risk.schoolName} · ${risk.riskType}'),
              subtitle: Text(risk.mitigation),
              trailing: Text('Score ${risk.riskScore}'),
              isThreeLine: true,
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
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
