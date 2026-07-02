import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../finance/inventory_finance/inventory_finance_models.dart';
import '../../finance/inventory_finance/inventory_finance_requests.dart';
import '../inventory_stock_provider.dart';

final List<TextInputFormatter> _digitsOnly = [
  FilteringTextInputFormatter.digitsOnly,
];

/// INV-1 — stock issue dialog. Surfaces the 422 InsufficientStock (and any other
/// server validation) as a friendly inline error under the fields.
Future<void> showIssueStockDialog(BuildContext context, WidgetRef ref) async {
  final skuController = TextEditingController();
  final qtyController = TextEditingController();
  final issuedToController = TextEditingController();
  final reasonController = TextEditingController();
  final errorText = ValueNotifier<String?>(null);
  final submitting = ValueNotifier<bool>(false);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Issue stock'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: QaTestKeys.inventoryStockIssueSkuField,
              controller: skuController,
              decoration: const InputDecoration(labelText: 'SKU'),
            ),
            TextField(
              key: QaTestKeys.inventoryStockIssueQtyField,
              controller: qtyController,
              keyboardType: TextInputType.number,
              inputFormatters: _digitsOnly,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            TextField(
              key: QaTestKeys.inventoryStockIssueIssuedToField,
              controller: issuedToController,
              decoration: const InputDecoration(labelText: 'Issued to'),
            ),
            TextField(
              key: QaTestKeys.inventoryStockIssueReasonField,
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: errorText,
              builder: (context, value, _) {
                if (value == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    value,
                    key: QaTestKeys.inventoryStockIssueErrorText,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: submitting,
          builder: (context, isSubmitting, _) => FilledButton(
            key: QaTestKeys.inventoryStockIssueSubmitButton,
            onPressed: isSubmitting
                ? null
                : () async {
                    errorText.value = null;
                    final sku = skuController.text.trim();
                    final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                    if (sku.isEmpty || qty <= 0) {
                      errorText.value = 'Enter a SKU and a quantity above 0.';
                      return;
                    }
                    submitting.value = true;
                    try {
                      final result = await ref
                          .read(issueStockProvider.notifier)
                          .execute(
                            IssueStockRequest(
                              sku: sku,
                              quantity: qty,
                              issuedTo: issuedToController.text.trim().isEmpty
                                  ? null
                                  : issuedToController.text.trim(),
                              reason: reasonController.text.trim().isEmpty
                                  ? null
                                  : reasonController.text.trim(),
                            ),
                          );
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          key: QaTestKeys.inventoryStockIssueSuccessSnackbar,
                          content: Text(
                            'Issue ${result.issueNumber} posted'
                            '${result.lowStockCount > 0 ? ' · ${result.lowStockCount} item(s) now low' : ''}',
                          ),
                        ),
                      );
                    } catch (error) {
                      submitting.value = false;
                      // Surface the 422 InsufficientStock inline (friendly).
                      errorText.value = aksharaErrorMessage(error);
                    }
                  },
            child: const Text('Post issue'),
          ),
        ),
      ],
    ),
  );
}

/// INV-3 — adjust dialog (in / out / opening). adjust_out is value-reducing and
/// goes to maker-checker approval (made clear in the UI copy + snackbar).
Future<void> showAdjustStockDialog(BuildContext context, WidgetRef ref) async {
  final skuController = TextEditingController();
  final qtyController = TextEditingController();
  final reasonController = TextEditingController();
  final movementType = ValueNotifier<String>('adjust_in');
  final errorText = ValueNotifier<String?>(null);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Adjust stock'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: QaTestKeys.inventoryStockAdjustSkuField,
              controller: skuController,
              decoration: const InputDecoration(labelText: 'SKU'),
            ),
            TextField(
              key: QaTestKeys.inventoryStockAdjustQtyField,
              controller: qtyController,
              keyboardType: TextInputType.number,
              inputFormatters: _digitsOnly,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            ValueListenableBuilder<String>(
              valueListenable: movementType,
              builder: (context, value, _) => DropdownButtonFormField<String>(
                key: QaTestKeys.inventoryStockAdjustTypeDropdown,
                initialValue: value,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'adjust_in',
                    child: Text('Adjust in (applies now)'),
                  ),
                  DropdownMenuItem(
                    value: 'opening',
                    child: Text('Opening balance (applies now)'),
                  ),
                  DropdownMenuItem(
                    value: 'adjust_out',
                    child: Text('Adjust out / write-off (needs approval)'),
                  ),
                ],
                onChanged: (v) => movementType.value = v ?? 'adjust_in',
              ),
            ),
            TextField(
              key: QaTestKeys.inventoryStockAdjustReasonField,
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason (required)'),
            ),
            ValueListenableBuilder<String>(
              valueListenable: movementType,
              builder: (context, value, _) => value == 'adjust_out'
                  ? const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Write-offs reduce inventory value, so this is queued '
                        'for a different user to approve in Write-offs.',
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: errorText,
              builder: (context, value, _) => value == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        value,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.inventoryStockAdjustSubmitButton,
          onPressed: () async {
            errorText.value = null;
            final sku = skuController.text.trim();
            final qty = int.tryParse(qtyController.text.trim()) ?? 0;
            final reason = reasonController.text.trim();
            if (sku.isEmpty || qty <= 0 || reason.isEmpty) {
              errorText.value = 'SKU, quantity (>0) and reason are required.';
              return;
            }
            try {
              final result =
                  await ref.read(adjustStockProvider.notifier).execute(
                        AdjustStockRequest(
                          sku: sku,
                          qty: qty,
                          movementType: movementType.value,
                          reason: reason,
                        ),
                      );
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              if (result.isPending) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    key: QaTestKeys.inventoryStockAdjustPendingSnackbar,
                    content: Text(
                      'Write-off submitted — awaiting approval in Write-offs',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    key: QaTestKeys.inventoryStockAdjustAppliedSnackbar,
                    content: Text(
                      'Adjustment applied · ${result.qtyBefore} → ${result.qtyAfter}',
                    ),
                  ),
                );
              }
            } catch (error) {
              errorText.value = aksharaErrorMessage(error);
            }
          },
          child: const Text('Submit'),
        ),
      ],
    ),
  );
}

/// INV-6 — stock-take / count. Shows the resulting variance; a NEGATIVE variance
/// is queued as a pending write-off.
Future<void> showStockCountDialog(BuildContext context, WidgetRef ref) async {
  final skuController = TextEditingController();
  final qtyController = TextEditingController();
  final variance = ValueNotifier<String?>(null);
  final errorText = ValueNotifier<String?>(null);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Stock take'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: QaTestKeys.inventoryStockCountSkuField,
              controller: skuController,
              decoration: const InputDecoration(labelText: 'SKU'),
            ),
            TextField(
              key: QaTestKeys.inventoryStockCountQtyField,
              controller: qtyController,
              keyboardType: TextInputType.number,
              inputFormatters: _digitsOnly,
              decoration: const InputDecoration(labelText: 'Counted quantity'),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: variance,
              builder: (context, value, _) => value == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        value,
                        key: QaTestKeys.inventoryStockCountVarianceText,
                      ),
                    ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: errorText,
              builder: (context, value, _) => value == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        value,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          key: QaTestKeys.inventoryStockCountSubmitButton,
          onPressed: () async {
            errorText.value = null;
            variance.value = null;
            final sku = skuController.text.trim();
            final counted = int.tryParse(qtyController.text.trim());
            if (sku.isEmpty || counted == null) {
              errorText.value = 'Enter a SKU and a counted quantity.';
              return;
            }
            try {
              final result =
                  await ref.read(recordStockCountProvider.notifier).execute(
                        RecordStockCountRequest(
                          sku: sku,
                          countedQty: counted,
                        ),
                      );
              final line = result.lines.isEmpty ? null : result.lines.first;
              if (line == null) {
                variance.value = 'Count session already posted.';
                return;
              }
              final sign = line.variance > 0
                  ? '+'
                  : (line.variance < 0 ? '' : '±');
              variance.value =
                  'System ${line.systemQty} · counted ${line.countedQty} · '
                  'variance $sign${line.variance}'
                  '${line.isPendingAdjustment ? ' — queued for approval' : (line.variance > 0 ? ' — applied' : '')}';
            } catch (error) {
              errorText.value = aksharaErrorMessage(error);
            }
          },
          child: const Text('Post count'),
        ),
      ],
    ),
  );
}

/// INV-2 — consumable registry + reorder-level CRUD.
Future<void> showUpsertStockItemDialog(
  BuildContext context,
  WidgetRef ref, {
  StockItem? existing,
}) async {
  final skuController = TextEditingController(text: existing?.sku ?? '');
  final nameController = TextEditingController(text: existing?.itemName ?? '');
  final reorderController =
      TextEditingController(text: existing?.reorderLevel.toString() ?? '');
  final itemType = ValueNotifier<StockItemType>(
    existing?.itemType ?? StockItemType.consumable,
  );
  final errorText = ValueNotifier<String?>(null);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(existing == null ? 'Add consumable' : 'Edit ${existing.sku}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: QaTestKeys.inventoryStockItemSkuField,
              controller: skuController,
              enabled: existing == null,
              decoration: const InputDecoration(labelText: 'SKU'),
            ),
            TextField(
              key: QaTestKeys.inventoryStockItemNameField,
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            TextField(
              key: QaTestKeys.inventoryStockItemReorderField,
              controller: reorderController,
              keyboardType: TextInputType.number,
              inputFormatters: _digitsOnly,
              decoration: const InputDecoration(labelText: 'Reorder level'),
            ),
            ValueListenableBuilder<StockItemType>(
              valueListenable: itemType,
              builder: (context, value, _) =>
                  DropdownButtonFormField<StockItemType>(
                key: QaTestKeys.inventoryStockItemTypeDropdown,
                initialValue: value,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: StockItemType.consumable,
                    child: Text('Consumable'),
                  ),
                  DropdownMenuItem(
                    value: StockItemType.asset,
                    child: Text('Asset'),
                  ),
                ],
                onChanged: (v) =>
                    itemType.value = v ?? StockItemType.consumable,
              ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: errorText,
              builder: (context, value, _) => value == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        value,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.inventoryStockItemSubmitButton,
          onPressed: () async {
            errorText.value = null;
            final sku = skuController.text.trim();
            if (sku.isEmpty) {
              errorText.value = 'SKU is required.';
              return;
            }
            try {
              final saved =
                  await ref.read(upsertStockItemProvider.notifier).execute(
                        UpsertStockItemRequest(
                          sku: sku,
                          itemName: nameController.text.trim().isEmpty
                              ? null
                              : nameController.text.trim(),
                          itemType: stockItemTypeToWire(itemType.value),
                          reorderLevel:
                              int.tryParse(reorderController.text.trim()) ?? 0,
                        ),
                      );
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  key: QaTestKeys.inventoryStockItemSavedSnackbar,
                  content: Text(
                    '${saved.sku} saved · reorder ${saved.reorderLevel}',
                  ),
                ),
              );
            } catch (error) {
              errorText.value = aksharaErrorMessage(error);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
