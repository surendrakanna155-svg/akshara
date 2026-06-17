import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/operational_action_feedback.dart';
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
                onPressed: () => showAksharaReportExportPreviewSnackBar(
                  context,
                  reportName: selectedReport.title,
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => showAksharaReportExportPreviewSnackBar(
                  context,
                  reportName: selectedReport.title,
                  format: 'Excel',
                ),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Export Excel'),
              ),
              OutlinedButton.icon(
                onPressed: () => showAksharaOperationalPreviewSnackBar(
                  context,
                  action: 'Email report',
                ),
                icon: const Icon(Icons.email_outlined),
                label: const Text('Email report'),
              ),
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
