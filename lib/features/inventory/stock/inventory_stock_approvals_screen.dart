import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
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

/// Maker-checker — pending value-reducing write-offs (manual adjust_out + negative
/// count variances) awaiting a checker. Approving/rejecting is manageInventory-
/// gated, and the approver must differ from the maker (the 409 SELF_APPROVE is
/// surfaced as a friendly snackbar).
class InventoryStockApprovalsScreen extends ConsumerWidget {
  const InventoryStockApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(inventoryPendingAdjustmentsFutureProvider);
    return InventoryModuleScaffold(
      screen: InventoryScreen.stockApprovals,
      showFilterBar: false,
      body: KeyedSubtree(
        key: QaTestKeys.inventoryStockApprovalsScreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AksharaSectionHeader(title: 'Pending write-offs'),
            const SizedBox(height: AksharaSpacing.s3),
            pending.when(
              loading: () => const AksharaLoadingState(
                semanticLabel: 'Loading pending write-offs',
              ),
              error: (e, _) =>
                  AksharaErrorState(message: aksharaErrorMessage(e)),
              data: (rows) {
                if (rows.isEmpty) {
                  return const AksharaEmptyState(
                    message: 'No write-offs awaiting approval.',
                    icon: Icons.verified_outlined,
                  );
                }
                return Column(
                  children: [
                    for (final adj in rows) _AdjustmentRow(adjustment: adj),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustmentRow extends ConsumerWidget {
  const _AdjustmentRow({required this.adjustment});

  final StockAdjustment adjustment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    return Card(
      key: QaTestKeys.inventoryStockApprovalRow(adjustment.id),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${adjustment.sku} · −${adjustment.qty}',
              style: text.titleSmall,
            ),
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              '${adjustment.sourceLabel} · ${adjustment.reason}',
              style: text.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s3),
            AksharaManageAction(
              permission: Permission.manageInventory,
              auditRoute: RouteNames.inventoryStockApprovals,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    key: QaTestKeys.inventoryStockRejectButton(adjustment.id),
                    onPressed: () => _decide(context, ref, approve: false),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  FilledButton(
                    key: QaTestKeys.inventoryStockApproveButton(adjustment.id),
                    onPressed: () => _decide(context, ref, approve: true),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    try {
      final notifier = ref.read(decideStockAdjustmentProvider.notifier);
      if (approve) {
        await notifier.approve(adjustment.id);
      } else {
        await notifier.reject(adjustment.id);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: approve
              ? QaTestKeys.inventoryStockApproveSuccessSnackbar
              : QaTestKeys.inventoryStockRejectSuccessSnackbar,
          content: Text(
            approve
                ? 'Write-off approved · ${adjustment.sku} decremented'
                : 'Write-off rejected · ${adjustment.sku} unchanged',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      // The 409 SELF_APPROVE_DENIED (checker == maker) surfaces here verbatim.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.inventoryStockApproveErrorSnackbar,
          content: Text(aksharaErrorMessage(error)),
        ),
      );
    }
  }
}
