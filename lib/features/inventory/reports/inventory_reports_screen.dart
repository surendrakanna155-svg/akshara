import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../inventory_models.dart';
import '../inventory_providers.dart';
import '../widgets/inventory_module_scaffold.dart';
import '../widgets/inventory_segment_panel.dart';
import '../widgets/inventory_trend_chart.dart';

/// INV-08 — Reports.
class InventoryReportsScreen extends ConsumerWidget {
  const InventoryReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(inventoryReportsLoadingProvider);
    final isError = ref.watch(inventoryReportsErrorProvider);
    final isEmpty = ref.watch(inventoryReportsEmptyProvider);
    final data = ref.watch(inventoryReportsProvider);

    return InventoryModuleScaffold(
      screen: InventoryScreen.reports,
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
    required InventoryReportsData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading inventory reports'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load inventory reports.',
      );
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No inventory reports available.',
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
        const SizedBox(height: AksharaSpacing.s4),
        Wrap(
          spacing: AksharaSpacing.s3,
          runSpacing: AksharaSpacing.s3,
          children: [
            OutlinedButton.icon(
              key: QaTestKeys.inventoryReportExportPdfButton,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    key: QaTestKeys.inventoryReportExportSuccessSnackbar,
                    content: Text(
                      'Inventory report export queued (${data.catalog.first.title})',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Export lifecycle & procurement PDF'),
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          InventoryTrendChart(
            title: 'Asset value trend (₹L)',
            points: data.assetValueTrend,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          InventorySegmentPanel(
            title: 'Allocation by department',
            segments: data.allocationByDept,
            height: chartHeight,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: InventoryTrendChart(
                  title: 'Asset value trend (₹L)',
                  points: data.assetValueTrend,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                flex: 2,
                child: InventorySegmentPanel(
                  title: 'Allocation by department',
                  segments: data.allocationByDept,
                  height: chartHeight,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        InventoryTrendChart(
          title: 'Procurement spend (₹L)',
          points: data.procurementTrend,
          height: chartHeight,
        ),
      ],
    );
  }
}

class _ReportCatalogList extends StatelessWidget {
  const _ReportCatalogList({required this.items});

  final List<InventoryReportCatalogItem> items;

  void _queueExport(BuildContext context, InventoryReportCatalogItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.inventoryReportExportSuccessSnackbar,
        content: Text('Report export queued (${item.title})'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                trailing: IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Download report',
                  onPressed: () => _queueExport(context, item),
                ),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s2),
          ],
        ],
      ),
    );
  }
}
