import 'package:flutter/material.dart';
import '../../../shared/widgets/operational_action_feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../library_models.dart';
import '../library_providers.dart';
import '../widgets/library_module_scaffold.dart';
import '../widgets/library_segment_panel.dart';
import '../widgets/library_trend_chart.dart';
import 'library_report_exporters.dart';

/// LB-08 — Library Reports.
class LibraryReportsScreen extends ConsumerWidget {
  const LibraryReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(libraryReportsLoadingProvider);
    final isError = ref.watch(libraryReportsErrorProvider);
    final isEmpty = ref.watch(libraryReportsEmptyProvider);
    final data = ref.watch(libraryReportsProvider);

    return LibraryModuleScaffold(
      screen: LibraryScreen.reports,
      showFilterBar: false,
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
    required LibraryReportsData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading library reports'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load library reports.',
      );
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No library reports available.',
        icon: Icons.assessment_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 300.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Report catalog'),
        const SizedBox(height: AksharaSpacing.s3),
        _ReportCatalogList(items: data.catalog),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          LibraryTrendChart(
            title: 'Monthly issues',
            points: data.issueTrend,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          LibrarySegmentPanel(
            title: 'Overdue by class',
            segments: data.overdueByClass,
            height: chartHeight,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: LibraryTrendChart(
                  title: 'Monthly issues',
                  points: data.issueTrend,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                flex: 2,
                child: LibrarySegmentPanel(
                  title: 'Overdue by class',
                  segments: data.overdueByClass,
                  height: chartHeight,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        LibrarySegmentPanel(
          title: 'Popular titles (issues)',
          segments: data.popularTitles,
          height: chartHeight,
        ),
      ],
    );
  }
}

/// LIB-1 — the overdue-loans report catalog id (`RPT-LB-002`); its download
/// button drives the real CSV/PDF export instead of the preview stub.
const String _overdueReportId = 'rpt_overdue';

class _ReportCatalogList extends ConsumerWidget {
  const _ReportCatalogList({required this.items});

  final List<LibraryReportCatalogItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Report catalog, ${items.length} reports',
      child: Column(
        children: [
          for (final item in items) ...[
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(item.title, style: text.titleSmall),
                subtitle: Text(
                  '${item.description} · Last: ${item.lastGenerated}',
                  style: text.bodySmall,
                ),
                trailing: item.id == _overdueReportId
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: QaTestKeys.libraryOverdueExportCsvButton,
                            icon: const Icon(Icons.table_view_outlined),
                            tooltip: 'Download CSV',
                            onPressed: () =>
                                _exportOverdue(context, ref, asPdf: false),
                          ),
                          IconButton(
                            key: QaTestKeys.libraryOverdueExportPdfButton,
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            tooltip: 'Download PDF',
                            onPressed: () =>
                                _exportOverdue(context, ref, asPdf: true),
                          ),
                        ],
                      )
                    : IconButton(
                        icon: const Icon(Icons.download_outlined),
                        tooltip: 'Download report',
                        onPressed: () => showAksharaReportExportPreviewSnackBar(
                          context,
                          reportName: 'Library report',
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s2),
          ],
        ],
      ),
    );
  }

  /// LIB-1 — real overdue-loans export (CSV / PDF, shared XCT-1 grid template).
  Future<void> _exportOverdue(
    BuildContext context,
    WidgetRef ref, {
    required bool asPdf,
  }) async {
    final loans = await ref.read(libraryOverdueFutureProvider.future);
    if (!context.mounted) return;
    if (loans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No overdue loans to export.')),
      );
      return;
    }
    final exporters =
        LibraryReportExporters(ref.read(aksharaReportExportServiceProvider));
    if (asPdf) {
      await exporters.shareOverduePdf(loans);
    } else {
      await exporters.shareOverdueCsv(loans);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Overdue loans ${asPdf ? 'PDF' : 'CSV'} ready (${loans.length} rows)',
        ),
      ),
    );
  }
}
