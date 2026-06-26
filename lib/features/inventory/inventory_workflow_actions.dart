import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../finance/inventory_finance/inventory_finance_models.dart';
import '../finance/inventory_finance/inventory_finance_requests.dart';
import 'inventory_models.dart';
import 'inventory_mutations_provider.dart';
import 'inventory_requests.dart';
import 'intelligence/inventory_intelligence_models.dart';
import 'vendors/inventory_vendor_catalog_provider.dart';

Future<void> showCreateProcurementOrderDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final itemsController = TextEditingController();
  final amountController = TextEditingController();
  InventoryFinanceVendor? selectedVendor;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create purchase order'),
      content: SingleChildScrollView(
        child: Consumer(
          builder: (context, dialogRef, _) {
            final vendors = dialogRef.watch(inventoryVendorCatalogProvider);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                vendors.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No vendors in the procurement catalog yet.',
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                showCreateInventoryVendorDialog(context, ref),
                            icon: const Icon(Icons.add_business_outlined),
                            label: const Text('Add a vendor'),
                          ),
                        ],
                      );
                    }
                    // Keep the selection valid against the latest catalog.
                    selectedVendor = list.firstWhere(
                      (v) => v.id == selectedVendor?.id,
                      orElse: () => list.first,
                    );
                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<InventoryFinanceVendor>(
                            key: QaTestKeys.inventoryPoVendorDropdown,
                            initialValue: selectedVendor,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Vendor'),
                            items: [
                              for (final v in list)
                                DropdownMenuItem(
                                  value: v,
                                  child: Text(v.displayName),
                                ),
                            ],
                            onChanged: (v) => selectedVendor = v,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add vendor',
                          icon: const Icon(Icons.add_business_outlined),
                          onPressed: () =>
                              showCreateInventoryVendorDialog(context, ref),
                        ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Could not load vendors: $e'),
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
            );
          },
        ),
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

  final vendor = selectedVendor;
  if (vendor == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select a vendor before creating a PO.')),
    );
    return;
  }

  try {
    final order =
        await ref.read(createProcurementOrderProvider.notifier).execute(
              CreateInventoryProcurementOrderRequest(
                vendorId: vendor.id,
                vendorName: vendor.displayName,
                items: itemsController.text.trim(),
                totalAmount: amountController.text.trim(),
                requestedBy: 'Procurement',
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

/// Creates a vendor in the finance procurement catalog so it can be selected
/// when raising a purchase order. Reachable from the PO dialog and the Vendors
/// directory screen.
Future<void> showCreateInventoryVendorDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final codeController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final gstController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add vendor'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Vendor code'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Contact phone'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Contact email'),
            ),
            TextField(
              controller: gstController,
              decoration: const InputDecoration(labelText: 'GSTIN'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.inventoryCreateVendorSubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Add vendor'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final code = codeController.text.trim();
  final name = nameController.text.trim();
  if (code.isEmpty || name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vendor code and name are required.')),
    );
    return;
  }

  try {
    final vendor = await ref.read(createInventoryVendorProvider.notifier).execute(
          CreateInventoryVendorRequest(
            vendorCode: code,
            displayName: name,
            contactPhone: phoneController.text.trim().isEmpty
                ? null
                : phoneController.text.trim(),
            contactEmail: emailController.text.trim().isEmpty
                ? null
                : emailController.text.trim(),
            gstin: gstController.text.trim().isEmpty
                ? null
                : gstController.text.trim(),
          ),
        );
    if (!context.mounted || vendor == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.inventoryVendorCreatedSnackbar,
        content: Text('Vendor ${vendor.displayName} added to the catalog'),
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
    await ref.read(receiveProcurementHandoffProvider.notifier).execute(order);
    if (!context.mounted) return;
    final receiveState = ref.read(receiveProcurementHandoffProvider);
    if (receiveState.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${receiveState.error}')),
      );
      return;
    }
    final result = receiveState.value;
    if (result == null) return;
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
