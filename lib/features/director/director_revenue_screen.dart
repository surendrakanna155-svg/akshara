import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/reports/akshara_report_export_service.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../admin/admin_layout.dart';
import '../copilot/copilot_context_provider.dart';
import 'director_models.dart';
import 'director_navigation.dart';
import 'director_providers.dart';
import 'reports/director_report_exporters.dart';
import 'widgets/director_metric_input_editor.dart';
import 'widgets/director_module_scaffold.dart';
import 'widgets/director_shared_widgets.dart';

class DirectorRevenueScreen extends ConsumerWidget {
  const DirectorRevenueScreen({super.key});

  static const _filters = ['All Schools', 'Current FY', 'Revenue Mix'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directorRevenueProvider);
    return CopilotContextScope(
      module: 'director',
      screen: 'Director Revenue Overview',
      child: DirectorModuleScaffold(
        screen: DirectorScreen.revenue,
        filters: _filters,
        filterTrailing: const DirectorAiAssistantLink(
          screenLabel: 'Director Revenue Overview',
        ),
        body: ErpAsyncBody<DirectorRevenueSnapshot>(
          state: resolveErpAsync(state, isDataEmpty: (_) => false),
          loadingLabel: 'Loading',
          emptyMessage: 'No revenue data available.',
          onRetry: () => ref.invalidate(directorRevenueProvider),
          builder: (revenue) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AksharaSpacing.s3,
                runSpacing: AksharaSpacing.s3,
                children: [
                  DirectorMetricTile(
                    label: 'Chain Revenue',
                    value: '${revenue.chainRevenueCr.toStringAsFixed(1)} Cr',
                  ),
                  DirectorMetricTile(
                    label: 'Expenses',
                    value: '${revenue.expensesCr.toStringAsFixed(1)} Cr',
                  ),
                  DirectorMetricTile(
                    label: 'Net',
                    value: '${revenue.netCr.toStringAsFixed(1)} Cr',
                  ),
                  DirectorMetricTile(
                    label: 'Margin',
                    value: '${revenue.marginPercent}%',
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s4),
              if (ref.watch(directorCanManageProvider))
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: QaTestKeys.directorManageInputsButton,
                    onPressed: () => showDirectorMetricInputEditor(context),
                    icon: const Icon(Icons.tune_outlined, size: 18),
                    label: const Text('Enter portfolio inputs'),
                  ),
                ),
              const SizedBox(height: AksharaSpacing.s4),
              const AksharaSectionHeader(title: 'School Revenue Table'),
              const SizedBox(height: AksharaSpacing.s3),
              _RevenueTable(schools: revenue.revenueBySchool),
              const SizedBox(height: AksharaSpacing.s5),
              // DIR-2 — consolidated collection report (per-school fee% +
              // billed/collected/outstanding + org totals) from its own provider.
              const _CollectionReportSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// DIR-2 — consolidated collection report section: per-school fee% + billed /
/// collected / outstanding, plus org totals, with its own CSV/PDF export.
class _CollectionReportSection extends ConsumerWidget {
  const _CollectionReportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directorCollectionReportProvider);
    return Column(
      key: QaTestKeys.directorCollectionReportSection,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Consolidated Collection Report'),
        const SizedBox(height: AksharaSpacing.s3),
        ErpAsyncBody<DirectorCollectionReport>(
          state: resolveErpAsync(state, isDataEmpty: (_) => false),
          loadingLabel: 'Loading',
          emptyMessage: 'No collection report available.',
          onRetry: () => ref.invalidate(directorCollectionReportProvider),
          builder: (report) => _CollectionReportBody(report: report),
        ),
      ],
    );
  }
}

class _CollectionReportBody extends ConsumerWidget {
  const _CollectionReportBody({required this.report});

  final DirectorCollectionReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AksharaSpacing.s3,
          runSpacing: AksharaSpacing.s3,
          children: [
            DirectorMetricTile(
              label: 'Billed',
              value: '₹${report.totals.billedInr}',
            ),
            DirectorMetricTile(
              label: 'Collected',
              value: '₹${report.totals.collectedInr}',
            ),
            DirectorMetricTile(
              label: 'Outstanding',
              value: '₹${report.totals.outstandingInr}',
            ),
            DirectorMetricTile(
              label: 'Fee Collection',
              value: '${report.totals.feeCollectionPercent}%',
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s3),
        Wrap(
          spacing: AksharaSpacing.s3,
          runSpacing: AksharaSpacing.s3,
          children: [
            OutlinedButton.icon(
              key: QaTestKeys.directorCollectionExportCsvButton,
              onPressed: () => _export(context, ref, pdf: false),
              icon: const Icon(Icons.table_chart_outlined, size: 18),
              label: const Text('Export CSV'),
            ),
            OutlinedButton.icon(
              key: QaTestKeys.directorCollectionExportPdfButton,
              onPressed: () => _export(context, ref, pdf: true),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Export PDF'),
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s3),
        _CollectionTable(report: report),
      ],
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref, {
    required bool pdf,
  }) async {
    final exporters =
        DirectorReportExporters(ref.read(aksharaReportExportServiceProvider));
    try {
      if (pdf) {
        await exporters.shareCollectionPdf(report);
      } else {
        await exporters.shareCollectionCsv(report);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.directorExportSnackbar,
          content: Text('Collection report exported (${pdf ? 'PDF' : 'CSV'})'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export collection report: $error')),
      );
    }
  }
}

class _CollectionTable extends StatelessWidget {
  const _CollectionTable({required this.report});

  final DirectorCollectionReport report;

  @override
  Widget build(BuildContext context) {
    final schools = report.schools;
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final row in schools) ...[
            _CollectionCard(row: row),
            const SizedBox(height: AksharaSpacing.s3),
          ],
          _CollectionTotalsCard(totals: report.totals),
        ],
      );
    }

    return AksharaVirtualizedDataTable(
      columns: const [
        DataColumn(label: Text('School')),
        DataColumn(label: Text('Fee %')),
        DataColumn(label: Text('Billed')),
        DataColumn(label: Text('Collected')),
        DataColumn(label: Text('Outstanding')),
      ],
      rowCount: schools.length,
      rowBuilder: (index) {
        final row = schools[index];
        return DataRow(
          cells: [
            DataCell(Text(row.name)),
            DataCell(Text('${row.feeCollectionPercent}%')),
            DataCell(Text('₹${row.billedInr}')),
            DataCell(Text('₹${row.collectedInr}')),
            DataCell(Text('₹${row.outstandingInr}')),
          ],
        );
      },
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.row});

  final DirectorCollectionRow row;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Semantics(
      label: 'Collection for ${row.name}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.name, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                'Fee ${row.feeCollectionPercent}% · Billed ₹${row.billedInr}',
                style: text.bodySmall,
              ),
              Text(
                'Collected ₹${row.collectedInr} · '
                'Outstanding ₹${row.outstandingInr}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionTotalsCard extends StatelessWidget {
  const _CollectionTotalsCard({required this.totals});

  final DirectorCollectionTotals totals;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Card(
      elevation: 0,
      color: context.colors.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Portfolio total', style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              'Fee ${totals.feeCollectionPercent}% · '
              'Billed ₹${totals.billedInr}',
              style: text.bodySmall,
            ),
            Text(
              'Collected ₹${totals.collectedInr} · '
              'Outstanding ₹${totals.outstandingInr}',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueTable extends StatelessWidget {
  const _RevenueTable({required this.schools});

  final List<DirectorSchoolRow> schools;

  @override
  Widget build(BuildContext context) {
    // Phones + portrait tablets collapse to stacked cards; landscape/desktop
    // keep the data table.
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final school in schools) ...[
            _RevenueCard(school: school),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return AksharaVirtualizedDataTable(
      columns: const [
        DataColumn(label: Text('School')),
        DataColumn(label: Text('Revenue')),
        DataColumn(label: Text('Students')),
        DataColumn(label: Text('Fee Collection %')),
        DataColumn(label: Text('Health')),
      ],
      rowCount: schools.length,
      rowBuilder: (index) {
        final school = schools[index];
        return DataRow(
          cells: [
            DataCell(Text(school.schoolName)),
            DataCell(Text('${school.revenueCr.toStringAsFixed(1)} Cr')),
            DataCell(Text('${school.students}')),
            DataCell(Text('${school.feeCollectionPercent}%')),
            DataCell(Text('${school.healthScore}')),
          ],
        );
      },
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.school});

  final DirectorSchoolRow school;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Semantics(
      label: 'School ${school.schoolName} revenue',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(school.schoolName, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                'Revenue ${school.revenueCr.toStringAsFixed(1)} Cr · '
                '${school.students} students',
                style: text.bodySmall,
              ),
              Text(
                'Fee collection ${school.feeCollectionPercent}% · '
                'Health ${school.healthScore}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
