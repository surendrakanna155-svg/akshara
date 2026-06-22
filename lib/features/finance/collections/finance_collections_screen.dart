import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';

import '../../../shared/widgets/widgets.dart';
import '../finance_workflow_actions.dart';
import '../finance_journey_context_provider.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../widgets/finance_kpi_row.dart';
import '../widgets/finance_module_scaffold.dart';
import 'finance_collections_provider.dart';

/// FN-05 — Collections.
class FinanceCollectionsScreen extends ConsumerWidget {
  const FinanceCollectionsScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Completed',
    'Pending',
    'Cash',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(financeCollectionsViewStateProvider);
    final pageResult = ref.watch(financeCollectionsPageResultProvider);
    final payments = ref.watch(financeFilteredCollectionsProvider);
    final summary = ref.watch(financeDailySummaryProvider);
    final filterIndex = ref.watch(financeCollectionFilterProvider);
    final receiptQuery = ref.watch(financeReceiptSearchProvider);
    final journeyInvoiceId = ref.watch(financeLastInvoiceIdProvider) ?? 'inv_1';

    return FinanceModuleScaffold(
      screen: FinanceScreen.collections,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(financeCollectionFilterProvider.notifier).state = index,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FinanceKpiRow(
            desktopColumns: 4,
            cardHeight: 100,
            kpis: [
              FinanceKpi(
                id: 'daily_total',
                value: summary.totalCollected,
                label: 'Collected today',
                icon: Icons.payments_outlined,
                accentName: 'success',
              ),
              FinanceKpi(
                id: 'txn_count',
                value: '${summary.transactionCount}',
                label: 'Transactions',
                icon: Icons.receipt_outlined,
                accentName: 'primary',
              ),
              FinanceKpi(
                id: 'cash',
                value: summary.cashAmount,
                label: 'Cash',
                icon: Icons.money_outlined,
                accentName: 'neutral',
              ),
              FinanceKpi(
                id: 'upi',
                value: summary.upiAmount,
                label: 'UPI / Digital',
                icon: Icons.phone_android_outlined,
                accentName: 'primary',
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s6),
          Wrap(
            spacing: AksharaSpacing.s3,
            runSpacing: AksharaSpacing.s2,
            children: [
              AksharaManageAction(
                permission: Permission.manageFinance,
                child: FilledButton.icon(
                  key: QaTestKeys.financeRecordCollectionButton,
                  onPressed: () => showRecordCollectionDialog(context, ref),
                  icon: const Icon(Icons.add_card_outlined),
                  label: const Text('Record collection'),
                ),
              ),
              AksharaManageAction(
                permission: Permission.manageFinance,
                child: OutlinedButton.icon(
                  key: QaTestKeys.financeQrPayButton,
                  onPressed: () => navigateToQrPaymentScreen(
                    context,
                    invoiceId: journeyInvoiceId,
                    amount: '5000',
                  ),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('QR Pay'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s4),
          Semantics(
            label: 'Receipt lookup',
            child: Material(
              child: TextField(
                key: QaTestKeys.financeReceiptSearchField,
                decoration: const InputDecoration(
                  labelText: 'Receipt or student lookup',
                  prefixIcon: Icon(Icons.search),
                  hintText: 'RCP-2026-8841',
                ),
                onChanged: (value) => ref
                    .read(financeReceiptSearchProvider.notifier)
                    .state = value,
              ),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          FinanceAsyncBody<PaginatedResult<CollectionPayment>>(
            state: viewState,
            loadingLabel: 'Loading collections',
            emptyMessage: receiptQuery.isEmpty
                ? 'No collection records for the selected filters.'
                : 'No receipts match "$receiptQuery".',
            emptyIcon: Icons.receipt_long_outlined,
            onRetry: () =>
                retryFinanceFuture(ref, financeCollectionsFutureProvider),
            builder: (result) {
              if (payments.isEmpty) {
                return AksharaEmptyState(
                  message: receiptQuery.isEmpty
                      ? 'No collection records for the selected filters.'
                      : 'No receipts match "$receiptQuery".',
                  icon: Icons.receipt_long_outlined,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AksharaSectionHeader(title: 'Payment list'),
                  const SizedBox(height: AksharaSpacing.s3),
                  if (AdminLayout.useCardLayout(context))
                    Column(
                      children: [
                        for (final payment in payments) ...[
                          _CollectionMobileCard(payment: payment),
                          const SizedBox(height: AksharaSpacing.s3),
                        ],
                      ],
                    )
                  else
                    _CollectionsTable(payments: payments),
                  if (pageResult != null)
                    AksharaPaginationBar<CollectionPayment>(
                      result: pageResult,
                      onPageChanged: (page) => ref
                          .read(financeCollectionsPageProvider.notifier)
                          .state = page,
                    ),
                  const SizedBox(height: AksharaSpacing.s6),
                  Wrap(
                    spacing: AksharaSpacing.s3,
                    runSpacing: AksharaSpacing.s2,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.go(RouteNames.financeReconciliation),
                        icon: const Icon(Icons.balance_outlined),
                        label: Text(
                          'Reconciliation (${summary.pendingReconciliation} pending)',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.go(RouteNames.financeOfflinePayments),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Offline payments'),
                      ),
                    ],
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

class _CollectionsTable extends StatelessWidget {
  const _CollectionsTable({required this.payments});

  final List<CollectionPayment> payments;

  static const _columns = [
    DataColumn(label: Text('Receipt')),
    DataColumn(label: Text('Student')),
    DataColumn(label: Text('Admission No.')),
    DataColumn(label: Text('Class')),
    DataColumn(label: Text('Amount')),
    DataColumn(label: Text('Mode')),
    DataColumn(label: Text('Collected')),
    DataColumn(label: Text('By')),
    DataColumn(label: Text('Status')),
  ];

  @override
  Widget build(BuildContext context) {
    return AksharaVirtualizedDataTable(
      columns: _columns,
      rowCount: payments.length,
      semanticLabel: 'Collections payment list, ${payments.length} items',
      rowBuilder: (index) {
        final payment = payments[index];
        return DataRow(
          onSelectChanged: (_) => context.go(
            RouteNames.financeCollectionDetail(payment.id),
          ),
          cells: [
            DataCell(Text(payment.receiptNumber)),
            DataCell(Text(payment.studentName)),
            DataCell(Text(payment.admissionNumber)),
            DataCell(Text(payment.classLabel)),
            DataCell(Text(payment.amount)),
            DataCell(Text(payment.mode)),
            DataCell(Text(payment.collectedAt)),
            DataCell(Text(payment.collectedBy)),
            DataCell(_CollectionStatusChip(status: payment.status)),
          ],
        );
      },
    );
  }
}

class _CollectionStatusChip extends StatelessWidget {
  const _CollectionStatusChip({required this.status});

  final CollectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      CollectionStatus.completed => ('Completed', KpiAccent.success),
      CollectionStatus.pending => ('Pending', KpiAccent.warning),
      CollectionStatus.failed => ('Failed', KpiAccent.error),
      CollectionStatus.refunded => ('Refunded', KpiAccent.primary),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _CollectionMobileCard extends StatelessWidget {
  const _CollectionMobileCard({required this.payment});

  final CollectionPayment payment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: () => context.go(RouteNames.financeCollectionDetail(payment.id)),
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(payment.receiptNumber, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(payment.studentName, style: text.bodyMedium),
              Text(
                '${payment.amount} · ${payment.mode} · ${payment.collectedAt}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              _CollectionStatusChip(status: payment.status),
            ],
          ),
        ),
      ),
    );
  }
}
