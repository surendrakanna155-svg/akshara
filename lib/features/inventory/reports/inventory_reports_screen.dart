import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../../finance/inventory_finance/inventory_finance_models.dart';
import '../inventory_models.dart';
import '../inventory_providers.dart';
import '../inventory_stock_provider.dart';
import '../widgets/inventory_module_scaffold.dart';
import '../widgets/inventory_segment_panel.dart';
import '../widgets/inventory_trend_chart.dart';

const List<String> _stockRegisterHeaders = [
  'Date',
  'SKU',
  'Movement',
  'Delta',
  'Before',
  'After',
  'Reason',
];

List<List<String>> _stockRegisterRows(List<StockRegisterRow> register) {
  return [
    for (final r in register)
      [
        r.createdAt.toIso8601String(),
        r.sku,
        r.movementLabel,
        '${r.quantityDelta}',
        '${r.qtyBefore}',
        '${r.qtyAfter}',
        r.reason,
      ],
  ];
}

const List<String> _lowStockHeaders = [
  'SKU',
  'Item',
  'On hand',
  'Reorder level',
  'Recommended qty',
];

List<List<String>> _lowStockRows(List<LowStockRow> rows) {
  return [
    for (final r in rows)
      [
        r.sku,
        r.itemName,
        '${r.quantityOnHand}',
        '${r.reorderLevel}',
        '${r.recommendedQuantity}',
      ],
  ];
}

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
        ref,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
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
        // INV-5 — real stock-register / low-stock exports (XCT-1 grid primitive).
        Wrap(
          spacing: AksharaSpacing.s3,
          runSpacing: AksharaSpacing.s3,
          children: [
            OutlinedButton.icon(
              key: QaTestKeys.inventoryStockRegisterExportCsvButton,
              onPressed: () => _exportStockRegisterCsv(context, ref),
              icon: const Icon(Icons.grid_on_outlined),
              label: const Text('Stock register CSV'),
            ),
            OutlinedButton.icon(
              key: QaTestKeys.inventoryReportExportPdfButton,
              onPressed: () => _exportStockRegisterPdf(context, ref),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Stock register PDF'),
            ),
            OutlinedButton.icon(
              key: QaTestKeys.inventoryStockRegisterExportPdfButton,
              onPressed: () => _exportLowStockCsv(context, ref),
              icon: const Icon(Icons.warning_amber_outlined),
              label: const Text('Low-stock CSV'),
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

  Future<void> _exportStockRegisterCsv(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final rows =
          await ref.read(inventoryFinanceStockRegisterForExportProvider.future);
      if (rows.isEmpty) {
        if (!context.mounted) return;
        _snack(context, 'No stock movements to export.');
        return;
      }
      await ref.read(aksharaReportExportServiceProvider).shareGridCsv(
            filename: 'stock_register',
            headers: _stockRegisterHeaders,
            rows: _stockRegisterRows(rows),
          );
      if (!context.mounted) return;
      _snack(context, 'Stock register CSV ready (${rows.length} rows)');
    } catch (error) {
      if (!context.mounted) return;
      _snack(context, aksharaErrorMessage(error), success: false);
    }
  }

  Future<void> _exportStockRegisterPdf(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final rows =
          await ref.read(inventoryFinanceStockRegisterForExportProvider.future);
      if (rows.isEmpty) {
        if (!context.mounted) return;
        _snack(context, 'No stock movements to export.');
        return;
      }
      await ref.read(aksharaReportExportServiceProvider).shareGridPdf(
            filename: 'stock_register',
            reportTitle: 'Stock register',
            moduleLabel: 'Inventory · Reports',
            headers: _stockRegisterHeaders,
            rows: _stockRegisterRows(rows),
            generatedAtLabel: DateTime.now().toIso8601String(),
            rightAlignFrom: 3,
          );
      if (!context.mounted) return;
      _snack(context, 'Stock register PDF ready (${rows.length} rows)');
    } catch (error) {
      if (!context.mounted) return;
      _snack(context, aksharaErrorMessage(error), success: false);
    }
  }

  Future<void> _exportLowStockCsv(BuildContext context, WidgetRef ref) async {
    try {
      final rows = await ref.read(inventoryLowStockFutureProvider.future);
      if (rows.isEmpty) {
        if (!context.mounted) return;
        _snack(context, 'No low-stock items to export.');
        return;
      }
      await ref.read(aksharaReportExportServiceProvider).shareGridCsv(
            filename: 'low_stock',
            headers: _lowStockHeaders,
            rows: _lowStockRows(rows),
          );
      if (!context.mounted) return;
      _snack(context, 'Low-stock CSV ready (${rows.length} items)');
    } catch (error) {
      if (!context.mounted) return;
      _snack(context, aksharaErrorMessage(error), success: false);
    }
  }

  void _snack(BuildContext context, String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: success ? QaTestKeys.inventoryReportExportSuccessSnackbar : null,
        content: Text(message),
      ),
    );
  }
}

/// A one-shot register fetch used by the reports export (kept separate from the
/// live stock-register provider so refreshing the report doesn't rebuild it).
final inventoryFinanceStockRegisterForExportProvider =
    FutureProvider.autoDispose<List<StockRegisterRow>>((ref) async {
  return ref.read(inventoryStockRegisterFutureProvider.future);
});

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
