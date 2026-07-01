import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../shared/widgets/widgets.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';
import '../admissions_navigation.dart';
import '../widgets/admissions_chart_panel.dart';
import '../widgets/admissions_module_scaffold.dart';
import 'admissions_reports_provider.dart';
import 'widgets/admissions_reports_tables.dart';

/// AD-09 — Admissions analytics and reports.
class AdmissionsReportsScreen extends ConsumerWidget {
  const AdmissionsReportsScreen({super.key});

  static const List<String> _tabs = [
    'Funnel',
    'Sources',
    'Counselors',
    'Applications',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(admissionsReportsViewStateProvider);
    final tab = ref.watch(admissionsReportsTabProvider);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.reports,
      filters: _tabs,
      selectedFilterIndex: AdmissionsReportTab.values.indexOf(tab),
      onFilterSelected: (index) => ref
          .read(admissionsReportsTabProvider.notifier)
          .state = AdmissionsReportTab.values[index],
      filterTrailing: OutlinedButton.icon(
        onPressed: () => _exportSelectedTab(context, ref, tab),
        icon: const Icon(Icons.download_outlined, size: 18),
        label: const Text('Export'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdmissionsAsyncBody<AdmissionsReportsData>(
            state: viewState,
            loadingLabel: 'Loading reports',
            emptyMessage: 'No report data for the selected period.',
            emptyIcon: Icons.analytics_outlined,
            onRetry: () =>
                retryAdmissionsFuture(ref, admissionsReportsFutureProvider),
            builder: (data) => _buildTabContent(data, tab),
          ),
        ],
      ),
    );
  }

  /// AD-09 export (XCT-1) — the currently-selected report tab as a real
  /// multi-column grid CSV (mirrors the on-screen table columns exactly).
  Future<void> _exportSelectedTab(
    BuildContext context,
    WidgetRef ref,
    AdmissionsReportTab tab,
  ) async {
    final data = ref.read(admissionsReportsFutureProvider).valueOrNull;
    if (data == null) {
      showAksharaExportQueuedSnackBar(
        context,
        label: 'Report data still loading — try again in a moment.',
      );
      return;
    }

    final String title;
    final List<String> headers;
    final List<List<String>> rows;
    switch (tab) {
      case AdmissionsReportTab.funnel:
        title = 'Admissions Funnel';
        headers = const ['Stage', 'Count'];
        rows = [for (final s in data.funnelSegments) [s.label, '${s.value}']];
      case AdmissionsReportTab.sources:
        title = 'Lead Sources';
        headers = const ['Source', 'Leads', 'Converted', 'Conversion %'];
        rows = [
          for (final r in data.sourceAnalysis)
            [
              r.source.label,
              '${r.leads}',
              '${r.converted}',
              '${r.conversionRate.toStringAsFixed(1)}%',
            ],
        ];
      case AdmissionsReportTab.counselors:
        title = 'Counselor Performance';
        headers = const [
          'Counselor',
          'Leads',
          'Applications',
          'Approved',
          'Conversion %',
        ];
        rows = [
          for (final r in data.counselorPerformance)
            [
              r.counselor,
              '${r.leads}',
              '${r.applications}',
              '${r.approved}',
              '${r.conversionRate.toStringAsFixed(1)}%',
            ],
        ];
      case AdmissionsReportTab.applications:
        title = 'Application Status';
        headers = const ['Status', 'Count', 'Share %'];
        rows = [
          for (final r in data.applicationStatus)
            [r.status.label, '${r.count}', '${r.percent.toStringAsFixed(1)}%'],
        ];
    }

    if (rows.isEmpty) {
      showAksharaExportQueuedSnackBar(
        context,
        label: 'No $title rows to export.',
      );
      return;
    }

    await ref.read(aksharaReportExportServiceProvider).shareGridCsv(
          filename: 'admissions_${tab.name}.csv',
          headers: headers,
          rows: rows,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title CSV ready (${rows.length} rows)')),
    );
  }

  Widget _buildTabContent(AdmissionsReportsData data, AdmissionsReportTab tab) {
    return switch (tab) {
      AdmissionsReportTab.funnel => AdmissionsChartPanel(
          title: 'Conversion funnel',
          segments: data.funnelSegments,
          height: 320,
        ),
      AdmissionsReportTab.sources => AdmissionsSourceReportTable(
          rows: data.sourceAnalysis,
        ),
      AdmissionsReportTab.counselors => AdmissionsCounselorReportTable(
          rows: data.counselorPerformance,
        ),
      AdmissionsReportTab.applications => AdmissionsApplicationReportTable(
          rows: data.applicationStatus,
        ),
    };
  }
}
