import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/reports/finance_audit_register_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../widgets/finance_collection_trend_chart.dart';
import '../../admin/admin_layout.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../widgets/finance_module_scaffold.dart';
import '../widgets/finance_responsive_grid.dart';
import 'finance_reports_provider.dart';

// PRA-P1-49 (S4): the finance report export must carry the report's real trend
// DATA — the exact period series the on-screen chart plots (value vs target, in
// ₹ lakhs) — not 3 catalog metadata rows. These ride the shared XCT-1 grid
// primitive (buildGridReportPdf / shareGridCsv), mirroring how HR and Attendance
// turn a report view-model into headers + string rows and export it.
const List<String> _financeReportGridHeaders = <String>[
  'Period',
  'Amount (₹ L)',
  'Target (₹ L)',
];

List<List<String>> _financeReportGridRows(List<FinanceReportTrendPoint> points) {
  return [
    for (final point in points)
      [
        point.label,
        point.value.toStringAsFixed(1),
        point.target.toStringAsFixed(1),
      ],
  ];
}

/// FN-10 — Finance reports catalog and trends.
class FinanceReportsScreen extends ConsumerWidget {
  const FinanceReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(financeReportsViewStateProvider);
    final selectedReportId = ref.watch(financeSelectedReportIdProvider);

    return FinanceModuleScaffold(
      screen: FinanceScreen.reports,
      showFilterBar: false,
      body: FinanceAsyncBody<FinanceReportsData>(
        state: viewState,
        loadingLabel: 'Loading finance reports',
        emptyMessage: 'No finance reports available.',
        emptyIcon: Icons.assessment_outlined,
        onRetry: () => retryFinanceFuture(ref, financeReportsFutureProvider),
        builder: (data) => _buildContent(
          context,
          ref: ref,
          data: data,
          selectedReportId: selectedReportId,
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required WidgetRef ref,
    required FinanceReportsData data,
    required String selectedReportId,
  }) {
    final selectedReport = data.catalog.firstWhere(
      (item) => item.id == selectedReportId,
      orElse: () => data.catalog.first,
    );
    final trendPoints = selectedReport.type == FinanceReportType.outstanding
        ? data.outstandingTrend
        : data.collectionTrend;
    final chartTitle = switch (selectedReport.type) {
      FinanceReportType.outstanding => 'Outstanding trend',
      FinanceReportType.discount => 'Discount impact trend',
      FinanceReportType.refund => 'Refund volume trend',
      FinanceReportType.collection => 'Collection trend',
    };
    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 300.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Report catalog'),
        const SizedBox(height: AksharaSpacing.s3),
        Semantics(
          container: true,
          label: 'Finance report catalog, ${data.catalog.length} reports',
          child: FinanceResponsiveGrid(
            desktopColumns: 2,
            tabletColumns: 2,
            mobileColumns: 1,
            children: [
              for (final report in data.catalog)
                _ReportCatalogCard(
                  report: report,
                  selected: report.id == selectedReportId,
                  onTap: () => ref
                      .read(financeSelectedReportIdProvider.notifier)
                      .state = report.id,
                ),
            ],
          ),
        ),
        const SizedBox(height: AksharaSpacing.s6),
        FinanceCollectionTrendChart(
          title: chartTitle,
          height: chartHeight,
          points: [
            for (final point in trendPoints)
              CollectionTrendPoint(
                label: point.label,
                amountLakhs: point.value,
                targetLakhs: point.target,
              ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s6),
        Semantics(
          label: 'Report export actions',
          child: Wrap(
            spacing: AksharaSpacing.s3,
            runSpacing: AksharaSpacing.s3,
            children: [
              OutlinedButton.icon(
                key: QaTestKeys.financeReportExportPdfButton,
                onPressed: () async {
                  final service = ref.read(aksharaReportExportServiceProvider);
                  // PRA-P1-49 (S4): export the selected report's real trend DATA
                  // (the same series the chart plots) as a grid, not 3 metadata
                  // rows. Only claim success when real rows were exported.
                  final rows = _financeReportGridRows(trendPoints);
                  if (rows.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'No data to export for ${selectedReport.title}',
                        ),
                      ),
                    );
                    return;
                  }
                  final bytes = await service.buildGridReportPdf(
                    reportTitle: selectedReport.title,
                    moduleLabel: 'Finance · ${selectedReport.type.name}',
                    generatedAtLabel: DateTime.now().toIso8601String(),
                    headers: _financeReportGridHeaders,
                    rows: rows,
                    rightAlignFrom: 1,
                  );
                  if (!context.mounted) return;
                  await service.previewPdf(
                    documentName: '${selectedReport.id}.pdf',
                    bytes: bytes,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      key: QaTestKeys.financeReportExportSuccessSnackbar,
                      content: Text(
                        '${selectedReport.title} PDF ready (${rows.length} rows)',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
              OutlinedButton.icon(
                key: QaTestKeys.financeReportExportExcelButton,
                onPressed: () async {
                  final service = ref.read(aksharaReportExportServiceProvider);
                  // PRA-P1-49 (S4): share the report's real trend DATA as a grid
                  // CSV (header row + one row per period), mirroring HR/Attendance
                  // — was previously 3 catalog-metadata key/value rows.
                  final rows = _financeReportGridRows(trendPoints);
                  if (rows.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'No data to export for ${selectedReport.title}',
                        ),
                      ),
                    );
                    return;
                  }
                  await service.shareGridCsv(
                    filename: '${selectedReport.id}.csv',
                    headers: _financeReportGridHeaders,
                    rows: rows,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      key: QaTestKeys.financeReportExportSuccessSnackbar,
                      content: Text(
                        '${selectedReport.title} Excel CSV ready '
                        '(${rows.length} rows)',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Export Excel'),
              ),
              OutlinedButton.icon(
                key: QaTestKeys.financeAuditRegisterExportButton,
                onPressed: () async {
                  final events =
                      await ref.read(financeAuditRegisterEventsProvider.future);
                  final registerService =
                      ref.read(financeAuditRegisterServiceProvider);
                  final exportService =
                      ref.read(aksharaReportExportServiceProvider);
                  final bytes = await registerService.buildRegisterPdf(
                    events: events,
                    generatedAtLabel: DateTime.now().toIso8601String(),
                  );
                  if (!context.mounted) return;
                  await exportService.previewPdf(
                    documentName: 'finance_audit_register.pdf',
                    bytes: bytes,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Finance audit register ready (${events.length} entries)',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Audit register'),
              ),
              // PRA-P1-50 (S0/T7): the "Email report" button was removed. It only
              // showed a "recorded in preview mode (no server write yet)" snackbar
              // — no report was ever scheduled or emailed. It sat next to working
              // PDF/Excel export buttons, advertising a capability that does not
              // exist. A real scheduled/emailed-report pipeline is future work.
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportCatalogCard extends StatelessWidget {
  const _ReportCatalogCard({
    required this.report,
    required this.selected,
    required this.onTap,
  });

  final FinanceReportCatalogItem report;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: true,
      selected: selected,
      label: '${report.title}, last generated ${report.lastGenerated}',
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(AksharaRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AksharaRadius.lg),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AksharaRadius.lg),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
              ),
            ),
            padding: const EdgeInsets.all(AksharaSpacing.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.title, style: text.titleSmall),
                const SizedBox(height: AksharaSpacing.s2),
                Text(report.description, style: text.bodySmall),
                const SizedBox(height: AksharaSpacing.s3),
                Text(
                  'Last generated: ${report.lastGenerated}',
                  style: text.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
