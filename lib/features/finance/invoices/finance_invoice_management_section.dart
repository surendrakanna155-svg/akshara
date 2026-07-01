import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../finance_workflow_actions.dart';
import '../policy/finance_policy_actions.dart';
import 'finance_invoices_provider.dart';

/// Invoice issue / cancel actions for draft and open invoices (P0 #6).
class FinanceInvoiceManagementSection extends ConsumerWidget {
  const FinanceInvoiceManagementSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(financeInvoicesViewStateProvider);
    final invoices = ref.watch(financeInvoicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Invoice management'),
        Text(
          'Issue draft invoices or cancel open invoices before collection.',
          style: context.aksharaText.bodyMedium,
        ),
        const SizedBox(height: AksharaSpacing.s4),
        FinanceAsyncBody<PaginatedResult<FinanceInvoice>>(
          state: viewState,
          loadingLabel: 'Loading invoices',
          emptyMessage: 'No invoices on file.',
          emptyIcon: Icons.receipt_outlined,
          onRetry: () =>
              retryFinanceFuture(ref, financeInvoicesFutureProvider),
          builder: (_) {
            if (invoices.isEmpty) {
              return const AksharaEmptyState(
                message: 'No invoices on file.',
                icon: Icons.receipt_outlined,
              );
            }
            return Column(
              children: [
                for (final invoice in invoices) ...[
                  _InvoiceActionCard(invoice: invoice),
                  const SizedBox(height: AksharaSpacing.s3),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InvoiceActionCard extends ConsumerWidget {
  const _InvoiceActionCard({required this.invoice});

  final FinanceInvoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;
    final canIssue = invoice.invoiceStatus == InvoiceStatus.draft;
    final canCancel = invoice.invoiceStatus == InvoiceStatus.issued ||
        invoice.invoiceStatus == InvoiceStatus.draft;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(invoice.invoiceNumber, style: text.titleSmall),
            Text(
              '${invoice.id} · ${invoice.termLabel} · ${invoice.totalAmount}',
              style: text.bodySmall,
            ),
            Text(
              'Status: ${invoice.invoiceStatus.name}',
              style: text.bodySmall,
            ),
            // FIN-D5: surface any accrued late fee so it is user-visible.
            if (invoice.hasLateFee)
              Padding(
                padding: const EdgeInsets.only(top: AksharaSpacing.s1),
                child: Row(
                  children: [
                    Icon(Icons.schedule_outlined,
                        size: 16, color: colors.error),
                    const SizedBox(width: AksharaSpacing.s1),
                    Text(
                      'Late fee: ₹${invoice.lateFeeAmount}',
                      style: text.bodySmall.copyWith(color: colors.error),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AksharaSpacing.s3),
            Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              children: [
                // FIN-D5: waive an accrued late fee (mandatory reason).
                if (invoice.hasLateFee)
                  AksharaManageAction(
                    permission: Permission.manageFinance,
                    child: OutlinedButton.icon(
                      key: QaTestKeys.financeWaiveLateFeeButton(invoice.id),
                      onPressed: () => showWaiveLateFeeDialog(
                        context,
                        ref,
                        invoiceId: invoice.id,
                        invoiceNumber: invoice.invoiceNumber,
                        lateFeeAmount: invoice.lateFeeAmount,
                      ),
                      icon: const Icon(Icons.money_off_outlined, size: 18),
                      label: const Text('Waive late fee'),
                    ),
                  ),
                if (canIssue)
                  AksharaManageAction(
                    permission: Permission.manageFinance,
                    child: FilledButton.icon(
                      key: QaTestKeys.financeIssueInvoiceButton(invoice.id),
                      onPressed: () => executeIssueInvoice(
                        context,
                        ref,
                        invoiceId: invoice.id,
                      ),
                      icon: const Icon(Icons.send_outlined, size: 18),
                      label: const Text('Issue invoice'),
                    ),
                  ),
                if (canCancel)
                  AksharaManageAction(
                    permission: Permission.manageFinance,
                    child: OutlinedButton.icon(
                      key: QaTestKeys.financeCancelInvoiceButton(invoice.id),
                      onPressed: () => executeCancelInvoice(
                        context,
                        ref,
                        invoiceId: invoice.id,
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel invoice'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
