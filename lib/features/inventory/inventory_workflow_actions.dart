import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import 'inventory_models.dart';
import 'inventory_mutations_provider.dart';
import 'inventory_requests.dart';
import 'intelligence/inventory_intelligence_models.dart';

Future<void> showCreateProcurementOrderDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final vendorController = TextEditingController(text: 'QA Vendor Supplies');
  final itemsController = TextEditingController(text: 'QA test items');
  final amountController = TextEditingController(text: '₹25,000');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create purchase order'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: vendorController,
            decoration: const InputDecoration(labelText: 'Vendor'),
          ),
          TextField(
            controller: itemsController,
            decoration: const InputDecoration(labelText: 'Items'),
          ),
          TextField(
            controller: amountController,
            decoration: const InputDecoration(labelText: 'Total amount'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Create draft PO'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final order =
        await ref.read(createProcurementOrderProvider.notifier).execute(
              CreateInventoryProcurementOrderRequest(
                vendorName: vendorController.text.trim(),
                items: itemsController.text.trim(),
                totalAmount: amountController.text.trim(),
                requestedBy: 'QA Procurement',
              ),
            );
    if (!context.mounted || order == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.inventoryPoSuccessSnackbar,
        content: Text('Draft PO ${order.poNumber} created'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error')));
  }
}

Future<void> showRecordAssetLifecycleEventDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final assetIdController = TextEditingController(text: 'asset_1');
  final assetTagController = TextEditingController(text: 'INV-AST-1042');
  final notesController = TextEditingController(text: 'QA lifecycle event');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Record lifecycle event'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: assetIdController,
            decoration: const InputDecoration(labelText: 'Asset ID'),
          ),
          TextField(
            controller: assetTagController,
            decoration: const InputDecoration(labelText: 'Asset tag'),
          ),
          TextField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Record'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(recordAssetLifecycleEventProvider.notifier).execute(
          RecordAssetLifecycleEventRequest(
            assetId: assetIdController.text.trim(),
            assetTag: assetTagController.text.trim(),
            eventType: AssetLifecycleEventType.distribution,
            notes: notesController.text.trim(),
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.inventoryLifecycleSuccessSnackbar,
        content: Text('Lifecycle event recorded'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error')));
  }
}

Future<void> submitProcurementReceiveHandoff(
  BuildContext context,
  WidgetRef ref,
  InventoryProcurementOrder order,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Record goods receipt'),
      content: Text(
        'Submit a goods receipt handoff to Finance for ${order.poNumber} '
        '(${order.financePoId})?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.inventoryPoReceiveHandoffDialogButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Record receipt'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final result = await ref
        .read(receiveProcurementHandoffProvider.notifier)
        .execute(order);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.inventoryPoReceiveHandoffSuccessSnackbar,
        content: Text(
          'Goods receipt ${result.grnNumber} queued for ${order.poNumber}',
        ),
        action: SnackBarAction(
          label: 'Finance',
          onPressed: () => context.go(RouteNames.financeReconciliation),
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error')));
  }
}

Future<void> submitProcurementApproveHandoff(
  BuildContext context,
  WidgetRef ref,
  InventoryProcurementOrder order,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Approve purchase order'),
      content: Text(
        'Approve ${order.poNumber} and sync Finance approval '
        'for ${order.financePoId}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.inventoryPoApproveHandoffDialogButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Approve PO'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final result = await ref
        .read(approveProcurementHandoffProvider.notifier)
        .execute(order);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.inventoryPoApproveHandoffSuccessSnackbar,
        content: Text(
          'PO ${order.poNumber} approved (${result.apCommitmentId})',
        ),
        action: SnackBarAction(
          label: 'Finance',
          onPressed: () => context.go(RouteNames.financeReconciliation),
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error')));
  }
}
