import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
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
      // Compact icon actions so both export formats fit the filter bar without
      // overflowing on narrow widths.
      filterTrailing: Wrap(
        spacing: AksharaSpacing.s1,
        children: [
          IconButton(
            key: QaTestKeys.admissionsReportExportCsvButton,
            tooltip: 'Export CSV',
            onPressed: () => _export(context, ref, tab, pdf: false),
            icon: const Icon(Icons.table_chart_outlined),
          ),
          IconButton(
            key: QaTestKeys.admissionsReportExportPdfButton,
            tooltip: 'Export PDF',
            onPressed: () => _export(context, ref, tab, pdf: true),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
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

  /// The currently-selected report tab as a (title, headers, rows) grid —
  /// shared by the CSV and PDF exports so both mirror the on-screen columns.
  (String, List<String>, List<List<String>>) _gridForTab(
    AdmissionsReportsData data,
    AdmissionsReportTab tab,
  ) {
    switch (tab) {
      case AdmissionsReportTab.funnel:
        return (
          'Admissions Funnel',
          const ['Stage', 'Count'],
          [
            for (final s in data.funnelSegments) [s.label, '${s.value}'],
            // ADM-D1: append the lost-reasons rollup so the funnel export is
            // complete (mirrors the on-screen lost-reasons card).
            for (final r in data.lostReasons)
              ['Lost · ${r.reason.label}', '${r.count}'],
          ],
        );
      case AdmissionsReportTab.sources:
        return (
          'Lead Sources',
          const ['Source', 'Leads', 'Converted', 'Conversion %'],
          [
            for (final r in data.sourceAnalysis)
              [
                r.source.label,
                '${r.leads}',
                '${r.converted}',
                '${r.conversionRate.toStringAsFixed(1)}%',
              ],
          ],
        );
      case AdmissionsReportTab.counselors:
        return (
          'Counselor Performance',
          const ['Counselor', 'Leads', 'Applications', 'Approved', 'Conversion %'],
          [
            for (final r in data.counselorPerformance)
              [
                r.counselor,
                '${r.leads}',
                '${r.applications}',
                '${r.approved}',
                '${r.conversionRate.toStringAsFixed(1)}%',
              ],
          ],
        );
      case AdmissionsReportTab.applications:
        return (
          'Application Status',
          const ['Status', 'Count', 'Share %'],
          [
            for (final r in data.applicationStatus)
              [r.status.label, '${r.count}', '${r.percent.toStringAsFixed(1)}%'],
          ],
        );
    }
  }

  /// AD-09 / ADM-1 export (XCT-1) — the selected report tab as a real
  /// multi-column grid, CSV or PDF, both through the shared export service.
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    AdmissionsReportTab tab, {
    required bool pdf,
  }) async {
    final data = ref.read(admissionsReportsFutureProvider).valueOrNull;
    if (data == null) {
      showAksharaExportQueuedSnackBar(
        context,
        label: 'Report data still loading — try again in a moment.',
      );
      return;
    }

    final (title, headers, rows) = _gridForTab(data, tab);
    if (rows.isEmpty) {
      showAksharaExportQueuedSnackBar(context, label: 'No $title rows to export.');
      return;
    }

    final service = ref.read(aksharaReportExportServiceProvider);
    if (pdf) {
      await service.shareGridPdf(
        filename: 'admissions_${tab.name}',
        reportTitle: title,
        moduleLabel: 'Admissions · Reports',
        headers: headers,
        rows: rows,
        rightAlignFrom: 1,
      );
    } else {
      await service.shareGridCsv(
        filename: 'admissions_${tab.name}.csv',
        headers: headers,
        rows: rows,
      );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title ${pdf ? 'PDF' : 'CSV'} ready (${rows.length} rows)',
        ),
      ),
    );
  }

  Widget _buildTabContent(AdmissionsReportsData data, AdmissionsReportTab tab) {
    return switch (tab) {
      // ADM-D1: the funnel tab also carries the lost-reasons rollup card.
      AdmissionsReportTab.funnel => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdmissionsChartPanel(
              title: 'Conversion funnel',
              segments: data.funnelSegments,
              height: 320,
            ),
            const SizedBox(height: AksharaSpacing.s6),
            AdmissionsLostReasonsCard(rows: data.lostReasons),
          ],
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
