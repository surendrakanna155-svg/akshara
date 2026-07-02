import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../finance/inventory_finance/inventory_finance_models.dart';
import '../inventory_models.dart';
import '../inventory_stock_provider.dart';
import '../widgets/inventory_module_scaffold.dart';
import 'inventory_stock_dialogs.dart';

/// INV-1..6 — the Store & Stock workspace: issue slips, manual adjustments,
/// physical counts, the consumable registry, low-stock (raise PO), and the
/// immutable stock register (CSV/PDF export). All mutations gate on
/// [Permission.manageInventory].
class InventoryStockScreen extends ConsumerWidget {
  const InventoryStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InventoryModuleScaffold(
      screen: InventoryScreen.stock,
      showFilterBar: false,
      body: KeyedSubtree(
        key: QaTestKeys.inventoryStockScreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _actionBar(context, ref),
            const SizedBox(height: AksharaSpacing.s4),
            const _LowStockSection(),
            const SizedBox(height: AksharaSpacing.s6),
            const _StockItemsSection(),
            const SizedBox(height: AksharaSpacing.s6),
            const _StockRegisterSection(),
          ],
        ),
      ),
    );
  }

  Widget _actionBar(BuildContext context, WidgetRef ref) {
    return AksharaManageAction(
      permission: Permission.manageInventory,
      auditRoute: RouteNames.inventoryStock,
      child: Wrap(
        spacing: AksharaSpacing.s3,
        runSpacing: AksharaSpacing.s3,
        children: [
          FilledButton.icon(
            key: QaTestKeys.inventoryStockIssueButton,
            onPressed: () => showIssueStockDialog(context, ref),
            icon: const Icon(Icons.outbox_outlined, size: 18),
            label: const Text('Issue stock'),
          ),
          OutlinedButton.icon(
            key: QaTestKeys.inventoryStockAdjustButton,
            onPressed: () => showAdjustStockDialog(context, ref),
            icon: const Icon(Icons.tune_outlined, size: 18),
            label: const Text('Adjust'),
          ),
          OutlinedButton.icon(
            key: QaTestKeys.inventoryStockCountButton,
            onPressed: () => showStockCountDialog(context, ref),
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('Stock take'),
          ),
          OutlinedButton.icon(
            key: QaTestKeys.inventoryStockItemAddButton,
            onPressed: () => showUpsertStockItemDialog(context, ref),
            icon: const Icon(Icons.add_box_outlined, size: 18),
            label: const Text('Add consumable'),
          ),
        ],
      ),
    );
  }
}

class _LowStockSection extends ConsumerWidget {
  const _LowStockSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStock = ref.watch(inventoryLowStockFutureProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Low stock'),
        const SizedBox(height: AksharaSpacing.s3),
        lowStock.when(
          loading: () => const AksharaLoadingState(
            semanticLabel: 'Loading low stock',
          ),
          error: (e, _) =>
              AksharaErrorState(message: aksharaErrorMessage(e)),
          data: (rows) {
            if (rows.isEmpty) {
              return const AksharaEmptyState(
                message: 'All items are above their reorder level.',
                icon: Icons.check_circle_outline,
              );
            }
            return Column(
              children: [
                for (final row in rows) _LowStockRowCard(row: row),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LowStockRowCard extends ConsumerWidget {
  const _LowStockRowCard({required this.row});

  final LowStockRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    final colors = context.colors;
    return Card(
      elevation: 0,
      child: ListTile(
        title: Text(row.itemName, style: text.titleSmall),
        subtitle: Text(
          '${row.sku} · ${row.quantityOnHand}/${row.reorderLevel} · '
          'recommend ${row.recommendedQuantity}',
          style: text.bodySmall.copyWith(color: colors.error),
        ),
        trailing: AksharaManageAction(
          permission: Permission.createInventoryPo,
          auditRoute: RouteNames.inventoryStock,
          child: FilledButton.tonal(
            key: QaTestKeys.inventoryLowStockRaisePoButton(row.sku),
            onPressed: () => _raisePo(context, ref, row),
            child: const Text('Raise PO'),
          ),
        ),
      ),
    );
  }

  Future<void> _raisePo(
    BuildContext context,
    WidgetRef ref,
    LowStockRow row,
  ) async {
    try {
      final po = await ref
          .read(raisePoFromLowStockProvider.notifier)
          .execute(row);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.inventoryLowStockRaisePoSuccessSnackbar,
          content: Text(
            'Draft PO ${po.poNumber} raised for ${row.sku} '
            '(${row.recommendedQuantity} units)',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(error))),
      );
    }
  }
}

class _StockItemsSection extends ConsumerWidget {
  const _StockItemsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inventoryStockItemsFutureProvider);
    return KeyedSubtree(
      key: QaTestKeys.inventoryStockItemsScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AksharaSectionHeader(title: 'Consumables & reorder levels'),
          const SizedBox(height: AksharaSpacing.s3),
          items.when(
            loading: () => const AksharaLoadingState(
              semanticLabel: 'Loading stock items',
            ),
            error: (e, _) =>
                AksharaErrorState(message: aksharaErrorMessage(e)),
            data: (rows) {
              if (rows.isEmpty) {
                return const AksharaEmptyState(
                  message: 'No stock items yet. Add a consumable to begin.',
                  icon: Icons.inventory_2_outlined,
                );
              }
              return Column(
                children: [
                  for (final item in rows)
                    Card(
                      elevation: 0,
                      child: ListTile(
                        leading: Icon(
                          item.itemType == StockItemType.asset
                              ? Icons.chair_outlined
                              : Icons.inventory_outlined,
                        ),
                        title: Text(item.itemName ?? item.sku),
                        subtitle: Text(
                          '${item.sku} · on hand ${item.quantityOnHand} · '
                          'reorder ${item.reorderLevel}',
                        ),
                        trailing: AksharaManageAction(
                          permission: Permission.manageInventory,
                          auditRoute: RouteNames.inventoryStock,
                          child: IconButton(
                            tooltip: 'Edit reorder level',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => showUpsertStockItemDialog(
                              context,
                              ref,
                              existing: item,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StockRegisterSection extends ConsumerWidget {
  const _StockRegisterSection();

  static const List<String> _headers = [
    'Date',
    'SKU',
    'Movement',
    'Delta',
    'Before',
    'After',
    'Reason',
  ];

  List<List<String>> _rows(List<StockRegisterRow> register) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final register = ref.watch(inventoryStockRegisterFutureProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: AksharaSectionHeader(title: 'Stock register'),
            ),
            register.maybeWhen(
              // Exports gate on the module MANAGE permission (house pattern —
              // mirrors the library overdue export); ManagePermissionGuard only
              // recognises manage-class permissions, so a view permission here
              // would hide the buttons for everyone.
              data: (rows) => AksharaManageAction(
                permission: Permission.manageInventory,
                auditRoute: RouteNames.inventoryStock,
                child: Wrap(
                  spacing: AksharaSpacing.s2,
                  children: [
                    OutlinedButton.icon(
                      key: QaTestKeys.inventoryStockRegisterExportCsvButton,
                      onPressed: rows.isEmpty
                          ? null
                          : () => _exportCsv(context, ref, rows),
                      icon: const Icon(Icons.grid_on_outlined, size: 18),
                      label: const Text('CSV'),
                    ),
                    OutlinedButton.icon(
                      key: QaTestKeys.inventoryStockRegisterExportPdfButton,
                      onPressed: rows.isEmpty
                          ? null
                          : () => _exportPdf(context, ref, rows),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('PDF'),
                    ),
                  ],
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s3),
        register.when(
          loading: () => const AksharaLoadingState(
            semanticLabel: 'Loading stock register',
          ),
          error: (e, _) => AksharaErrorState(message: aksharaErrorMessage(e)),
          data: (rows) {
            if (rows.isEmpty) {
              return const AksharaEmptyState(
                message: 'No stock movements recorded yet.',
                icon: Icons.receipt_long_outlined,
              );
            }
            return Column(
              children: [
                for (final r in rows.take(50))
                  Card(
                    elevation: 0,
                    child: ListTile(
                      dense: true,
                      title: Text('${r.sku} · ${r.movementLabel}'),
                      subtitle: Text(
                        '${r.qtyBefore} → ${r.qtyAfter} '
                        '(${r.quantityDelta >= 0 ? '+' : ''}${r.quantityDelta}) · ${r.reason}',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// INV-5 — real CSV export over the stock register (XCT-1 grid primitive).
  Future<void> _exportCsv(
    BuildContext context,
    WidgetRef ref,
    List<StockRegisterRow> rows,
  ) async {
    await ref.read(aksharaReportExportServiceProvider).shareGridCsv(
          filename: 'stock_register',
          headers: _headers,
          rows: _rows(rows),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.inventoryReportExportSuccessSnackbar,
        content: Text('Stock register CSV ready (${rows.length} rows)'),
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    WidgetRef ref,
    List<StockRegisterRow> rows,
  ) async {
    await ref.read(aksharaReportExportServiceProvider).shareGridPdf(
          filename: 'stock_register',
          reportTitle: 'Stock register',
          moduleLabel: 'Inventory · Store & Stock',
          headers: _headers,
          rows: _rows(rows),
          generatedAtLabel: DateTime.now().toIso8601String(),
          rightAlignFrom: 3,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.inventoryReportExportSuccessSnackbar,
        content: Text('Stock register PDF ready (${rows.length} rows)'),
      ),
    );
  }
}
