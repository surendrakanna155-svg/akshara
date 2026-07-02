import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_surface_card.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hr_models.dart';
import '../widgets/hr_module_scaffold.dart';
import 'hr_export_providers.dart';
import 'hr_report_exporters.dart';
import 'hr_reports_provider.dart';

/// HR-10 — HR reports catalog (headcount, attendance, leave, payroll).
class HrReportsScreen extends ConsumerWidget {
  const HrReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(hrReportsViewStateProvider);
    final selectedReportId = ref.watch(hrSelectedReportIdProvider);

    return HrModuleScaffold(
      screen: HrScreen.reports,
      showFilterBar: false,
      body: ErpAsyncBody<HrReportsData>(
        state: viewState,
        loadingLabel: 'Loading HR reports',
        emptyMessage: 'No HR reports available.',
        emptyIcon: Icons.assessment_outlined,
        onRetry: () => retryErpFuture(ref, hrReportsFutureProvider),
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
    required HrReportsData data,
    required String selectedReportId,
  }) {
    final selected = data.catalog.firstWhere(
      (item) => item.id == selectedReportId,
      orElse: () => data.catalog.first,
    );
    final isMobile = AdminLayout.isMobile(context);
    final columns = isMobile ? 1 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AksharaSurfaceCard(
          child: Text(
            data.headlineMetric,
            style: context.aksharaText.titleMedium,
          ),
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Report catalog'),
        const SizedBox(height: AksharaSpacing.s3),
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AksharaSpacing.s3,
          mainAxisSpacing: AksharaSpacing.s3,
          childAspectRatio: isMobile ? 2.4 : 2.8,
          children: [
            for (final report in data.catalog)
              AksharaSurfaceCard(
                onTap: () =>
                    ref.read(hrSelectedReportIdProvider.notifier).state =
                        report.id,
                child: Row(
                  children: [
                    Icon(
                      report.icon,
                      color: report.id == selectedReportId
                          ? context.colors.primary
                          : context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AksharaSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(report.title, style: context.aksharaText.titleSmall),
                          Text(
                            report.description,
                            style: context.aksharaText.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s6),
        Wrap(
          spacing: AksharaSpacing.s3,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final service = ref.read(aksharaReportExportServiceProvider);
                final bytes = await service.buildTabularReportPdf(
                  reportTitle: selected.title,
                  moduleLabel: 'HR · Reports',
                  generatedAtLabel: DateTime.now().toIso8601String(),
                  rows: _exportRows(data: data, selected: selected),
                );
                if (!context.mounted) return;
                await service.previewPdf(
                  documentName: '${selected.id}.pdf',
                  bytes: bytes,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${selected.title} PDF ready')),
                );
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Export PDF'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final service = ref.read(aksharaReportExportServiceProvider);
                final rows = _exportRows(data: data, selected: selected);
                await service.shareTabularCsv(
                  filename: '${selected.id}.csv',
                  reportTitle: selected.title,
                  rows: rows,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${selected.title} Excel CSV ready')),
                );
              },
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Export Excel'),
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Live report exports'),
        const SizedBox(height: AksharaSpacing.s3),
        const _LiveReportExports(),
      ],
    );
  }

  // (kept below the widget so the class body stays readable)

  /// Builds the export rows for the selected report tile from live HR reports
  /// data (headline metric + the selected report's catalog metadata).
  List<MapEntry<String, String>> _exportRows({
    required HrReportsData data,
    required HrReportCatalogItem selected,
  }) {
    return [
      MapEntry('Report', selected.title),
      MapEntry('Report ID', selected.id),
      MapEntry('Description', selected.description),
      MapEntry('Headline metric', data.headlineMetric),
    ];
  }
}

/// HR-4 (leave balances) + HR-5 (headcount) live exports — each fetched from the
/// backend on tap and shared as a grid CSV / PDF via the shared XCT-1 service.
class _LiveReportExports extends ConsumerWidget {
  const _LiveReportExports();

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(HrReportExporters exporters) action,
    String label,
  ) async {
    final exporters =
        HrReportExporters(ref.read(aksharaReportExportServiceProvider));
    try {
      await action(exporters);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.hrReportExportSuccessSnackbar,
          content: Text(label),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to build the export.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Live HR report export actions',
      child: Wrap(
        spacing: AksharaSpacing.s3,
        runSpacing: AksharaSpacing.s3,
        children: [
          OutlinedButton.icon(
            key: QaTestKeys.hrHeadcountExportButton,
            onPressed: () => _run(
              context,
              ref,
              (e) async {
                final report = await ref.read(hrHeadcountProvider.future);
                await e.shareHeadcountPdf(report);
              },
              'Headcount by department PDF ready',
            ),
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Headcount PDF'),
          ),
          OutlinedButton.icon(
            onPressed: () => _run(
              context,
              ref,
              (e) async {
                final report = await ref.read(hrHeadcountProvider.future);
                await e.shareHeadcountCsv(report);
              },
              'Headcount by department Excel CSV ready',
            ),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Headcount Excel'),
          ),
          OutlinedButton.icon(
            key: QaTestKeys.hrLeaveBalancesExportButton,
            onPressed: () => _run(
              context,
              ref,
              (e) async {
                final report = await ref.read(hrLeaveBalancesProvider.future);
                await e.shareLeaveBalancesPdf(report);
              },
              'Leave balances PDF ready',
            ),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Leave balances PDF'),
          ),
          OutlinedButton.icon(
            onPressed: () => _run(
              context,
              ref,
              (e) async {
                final report = await ref.read(hrLeaveBalancesProvider.future);
                await e.shareLeaveBalancesCsv(report);
              },
              'Leave balances Excel CSV ready',
            ),
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Leave balances Excel'),
          ),
          // HR-D1 — staff documents expiring within 30 days.
          OutlinedButton.icon(
            key: QaTestKeys.hrExpiringDocsExportButton,
            onPressed: () => _run(
              context,
              ref,
              (e) async {
                final report =
                    await ref.read(hrExpiringDocumentsExportProvider.future);
                await e.shareExpiringDocsPdf(report);
              },
              'Expiring documents PDF ready',
            ),
            icon: const Icon(Icons.event_busy_outlined),
            label: const Text('Expiring documents PDF'),
          ),
          // HR-D2 — employees whose probation ends within 15 days.
          OutlinedButton.icon(
            key: QaTestKeys.hrProbationEndingExportButton,
            onPressed: () => _run(
              context,
              ref,
              (e) async {
                final report =
                    await ref.read(hrProbationEndingExportProvider.future);
                await e.shareProbationEndingPdf(report);
              },
              'Probation ending PDF ready',
            ),
            icon: const Icon(Icons.timelapse_outlined),
            label: const Text('Probation ending PDF'),
          ),
        ],
      ),
    );
  }
}
