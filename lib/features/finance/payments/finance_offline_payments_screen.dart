import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../finance_mutations_provider.dart';
import '../finance_payments_provider.dart';
import '../finance_requests.dart';
import '../widgets/finance_module_scaffold.dart';

class FinanceOfflinePaymentsScreen extends ConsumerWidget {
  const FinanceOfflinePaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlinePaymentsViewStateProvider);
    final selectedTab = ref.watch(offlinePaymentsTabProvider);
    final payments = ref.watch(selectedOfflinePaymentsProvider);

    return FinanceModuleScaffold(
      screen: FinanceScreen.offlinePayments,
      showFilterBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('Pending')),
              ButtonSegment<int>(value: 1, label: Text('Reconciled')),
            ],
            selected: {selectedTab},
            onSelectionChanged: (selection) {
              ref.read(offlinePaymentsTabProvider.notifier).state =
                  selection.first;
            },
          ),
          const SizedBox(height: AksharaSpacing.s4),
          FinanceAsyncBody<PaginatedResult<OfflinePaymentRecord>>(
            state: state,
            loadingLabel: 'Loading offline payments',
            emptyMessage: selectedTab == 0
                ? 'No pending offline payments.'
                : 'No reconciled offline payments.',
            emptyIcon: Icons.receipt_long_outlined,
            onRetry: () =>
                retryFinanceFuture(ref, offlinePaymentsFutureProvider),
            builder: (_) {
              if (payments.isEmpty) {
                return AksharaEmptyState(
                  message: selectedTab == 0
                      ? 'No pending offline payments.'
                      : 'No reconciled offline payments.',
                  icon: Icons.receipt_long_outlined,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AksharaSectionHeader(title: 'Offline payment records'),
                  const SizedBox(height: AksharaSpacing.s3),
                  if (AdminLayout.useCardLayout(context))
                    Column(
                      children: [
                        for (final payment in payments) ...[
                          _OfflinePaymentCard(payment: payment),
                          const SizedBox(height: AksharaSpacing.s3),
                        ],
                      ],
                    )
                  else
                    _OfflinePaymentsTable(payments: payments),
                ],
              );
            },
          ),
          const SizedBox(height: AksharaSpacing.s4),
          Align(
            alignment: Alignment.bottomRight,
            child: AksharaManageAction(
              permission: Permission.manageFinance,
              child: FloatingActionButton.extended(
                key: QaTestKeys.financeRecordOfflinePaymentFab,
                onPressed: () => _showRecordOfflinePaymentDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Record offline payment'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflinePaymentsTable extends ConsumerWidget {
  const _OfflinePaymentsTable({required this.payments});

  final List<OfflinePaymentRecord> payments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AksharaVirtualizedDataTable(
      columns: const [
        DataColumn(label: Text('Invoice')),
        DataColumn(label: Text('Student')),
        DataColumn(label: Text('Amount')),
        DataColumn(label: Text('Method')),
        DataColumn(label: Text('Reference')),
        DataColumn(label: Text('Recorded')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Action')),
      ],
      rowCount: payments.length,
      semanticLabel: 'Offline payments table',
      rowBuilder: (index) {
        final payment = payments[index];
        return DataRow(
          cells: [
            DataCell(Text(payment.invoiceId)),
            DataCell(Text(payment.studentName)),
            DataCell(Text(payment.amount)),
            DataCell(Text(_paymentMethodLabel(payment.method))),
            DataCell(Text(payment.referenceNumber)),
            DataCell(Text(payment.recordedAt)),
            DataCell(_StatusChip(status: payment.status)),
            DataCell(
              payment.status == OfflinePaymentStatus.pendingReconciliation
                  ? AksharaManageAction(
                      permission: Permission.manageFinance,
                      child: TextButton(
                        key: QaTestKeys.financeReconcileOfflinePaymentButton(
                          payment.id,
                        ),
                        onPressed: () async {
                          final notifier = ref.read(
                            reconcileOfflinePaymentProvider.notifier,
                          );
                          final result = await notifier.execute(
                            offlinePaymentId: payment.id,
                          );
                          if (!context.mounted) return;
                          // RT-26: surface a failed reconcile instead of
                          // silently returning (it returns null on error).
                          if (result == null) {
                            final failure = ref
                                .read(reconcileOfflinePaymentProvider)
                                .error;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  failure != null
                                      ? aksharaErrorMessage(failure)
                                      : 'Could not reconcile this payment. Please try again.',
                                ),
                              ),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              key: QaTestKeys
                                  .financeOfflinePaymentReconcileSuccessSnackbar,
                              content: Text('Offline payment reconciled.'),
                            ),
                          );
                        },
                        child: const Text('Reconcile'),
                      ),
                    )
                  : Text(payment.collectionId ?? '—'),
            ),
          ],
        );
      },
    );
  }
}

class _OfflinePaymentCard extends ConsumerWidget {
  const _OfflinePaymentCard({required this.payment});

  final OfflinePaymentRecord payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    final colors = context.colors;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(payment.studentName, style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              '${payment.amount} • ${_paymentMethodLabel(payment.method)} • ${payment.recordedAt}',
              style: text.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            _StatusChip(status: payment.status),
            if (payment.status == OfflinePaymentStatus.pendingReconciliation)
              Align(
                alignment: Alignment.centerRight,
                child: AksharaManageAction(
                  permission: Permission.manageFinance,
                  child: TextButton(
                    key: QaTestKeys.financeReconcileOfflinePaymentButton(
                      payment.id,
                    ),
                    onPressed: () async {
                      final notifier =
                          ref.read(reconcileOfflinePaymentProvider.notifier);
                      final result = await notifier.execute(
                        offlinePaymentId: payment.id,
                      );
                      if (!context.mounted || result == null) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          key: QaTestKeys
                              .financeOfflinePaymentReconcileSuccessSnackbar,
                          content: Text('Offline payment reconciled.'),
                        ),
                      );
                    },
                    child: const Text('Reconcile'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OfflinePaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      OfflinePaymentStatus.pendingReconciliation => (
          'Pending',
          KpiAccent.warning
        ),
      OfflinePaymentStatus.reconciled => ('Reconciled', KpiAccent.success),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

Future<void> _showRecordOfflinePaymentDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final invoiceController = TextEditingController(text: 'inv_1');
  final studentController = TextEditingController();
  final amountController = TextEditingController();
  final referenceController = TextEditingController();
  var method = OfflinePaymentMethod.cash;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Record offline payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: QaTestKeys.financeOfflinePaymentInvoiceField,
                    controller: invoiceController,
                    decoration: const InputDecoration(labelText: 'Invoice ID'),
                  ),
                  const SizedBox(height: AksharaSpacing.s3),
                  TextField(
                    key: QaTestKeys.financeOfflinePaymentStudentField,
                    controller: studentController,
                    decoration:
                        const InputDecoration(labelText: 'Student name'),
                  ),
                  const SizedBox(height: AksharaSpacing.s3),
                  TextField(
                    key: QaTestKeys.financeOfflinePaymentAmountField,
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AksharaSpacing.s3),
                  DropdownButtonFormField<OfflinePaymentMethod>(
                    initialValue: method,
                    items: const [
                      DropdownMenuItem(
                        value: OfflinePaymentMethod.cash,
                        child: Text('Cash'),
                      ),
                      DropdownMenuItem(
                        value: OfflinePaymentMethod.cheque,
                        child: Text('Cheque'),
                      ),
                      DropdownMenuItem(
                        value: OfflinePaymentMethod.dd,
                        child: Text('Demand Draft'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => method = value);
                    },
                    decoration: const InputDecoration(labelText: 'Method'),
                  ),
                  const SizedBox(height: AksharaSpacing.s3),
                  TextField(
                    key: QaTestKeys.financeOfflinePaymentReferenceField,
                    controller: referenceController,
                    decoration:
                        const InputDecoration(labelText: 'Reference number'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: QaTestKeys.financeOfflinePaymentSubmitButton,
                onPressed: () async {
                  final notifier =
                      ref.read(recordOfflinePaymentProvider.notifier);
                  final result = await notifier.execute(
                    RecordOfflinePaymentRequest(
                      invoiceId: invoiceController.text.trim(),
                      studentName: studentController.text.trim(),
                      amount: amountController.text.trim(),
                      method: method,
                      referenceNumber: referenceController.text.trim(),
                      recordedAt: DateTime.now().toIso8601String(),
                    ),
                  );
                  if (!context.mounted) return;
                  // RT-26: surface a failed record instead of silently closing
                  // (execute returns null on error) — the dialog stays open so
                  // the user can correct and retry.
                  if (result == null) {
                    final failure =
                        ref.read(recordOfflinePaymentProvider).error;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          failure != null
                              ? aksharaErrorMessage(failure)
                              : 'Could not record this payment. Please try again.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      key: QaTestKeys.financeOfflinePaymentSuccessSnackbar,
                      content: Text('Offline payment recorded.'),
                    ),
                  );
                },
                child: const Text('Record'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _paymentMethodLabel(OfflinePaymentMethod method) => switch (method) {
      OfflinePaymentMethod.cash => 'Cash',
      OfflinePaymentMethod.cheque => 'Cheque',
      OfflinePaymentMethod.dd => 'DD',
    };
