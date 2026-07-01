import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';

import '../../../shared/widgets/widgets.dart';
import '../../school_completion/school_branding_theme_provider.dart';
import '../finance_mutations_provider.dart';
import '../finance_workflow_actions.dart';
import '../finance_journey_context_provider.dart';
import '../policy/finance_policy_actions.dart';
import '../policy/finance_policy_provider.dart';
import '../receipts/finance_receipt_pdf_service.dart';
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
              // FIN-D5 / FIN-D3: policy actions kept in a compact overflow menu
              // so the mobile action row never overflows (~390px width history).
              AksharaManageAction(
                permission: Permission.manageFinance,
                child: PopupMenuButton<String>(
                  key: QaTestKeys.financeCollectionsPolicyMenu,
                  tooltip: 'More collection actions',
                  onSelected: (value) {
                    switch (value) {
                      case 'accrue':
                        accrueLateFees(context, ref);
                      case 'cancelled':
                        exportCancelledRegister(context, ref);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      key: QaTestKeys.financeAccrueLateFeesButton,
                      value: 'accrue',
                      child: ListTile(
                        leading: Icon(Icons.schedule_outlined),
                        title: Text('Accrue late fees'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem<String>(
                      key: QaTestKeys.financeCancelledRegisterButton,
                      value: 'cancelled',
                      child: ListTile(
                        leading: Icon(Icons.receipt_long_outlined),
                        title: Text('Cancelled register'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AksharaSpacing.s3,
                      vertical: AksharaSpacing.s2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.more_horiz),
                        SizedBox(width: AksharaSpacing.s1),
                        Text('More'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s4),
          const _DayCloseControl(),
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
                      // FIN-1: daily collection summary export (mode-wise).
                      OutlinedButton.icon(
                        onPressed: () => _exportSummary(context, ref, summary),
                        icon: const Icon(Icons.summarize_outlined),
                        label: const Text('Export summary'),
                      ),
                      // FIN-7: day collection report (transaction-level export).
                      OutlinedButton.icon(
                        onPressed: () =>
                            _exportCollections(context, ref, payments),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Export collections'),
                      ),
                      // FIN-5: batch receipt printing.
                      AksharaManageAction(
                        permission: Permission.manageFinance,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _printReceipts(context, ref, payments),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Print receipts'),
                        ),
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

  /// FIN-1: export the day's mode-wise collection summary as a CSV.
  Future<void> _exportSummary(
    BuildContext context,
    WidgetRef ref,
    DailyCollectionSummary summary,
  ) async {
    await ref.read(aksharaReportExportServiceProvider).shareTabularCsv(
      filename: 'daily_collection_summary.csv',
      reportTitle: 'Daily Collection Summary — ${summary.dateLabel}',
      rows: [
        MapEntry('Date', summary.dateLabel),
        MapEntry('Total collected', summary.totalCollected),
        MapEntry('Transactions', '${summary.transactionCount}'),
        MapEntry('Cash', summary.cashAmount),
        MapEntry('UPI / Digital', summary.upiAmount),
        MapEntry('Pending reconciliation', '${summary.pendingReconciliation}'),
      ],
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Daily collection summary CSV ready')),
    );
  }

  /// FIN-7: export the loaded collections as a transaction-level grid CSV.
  Future<void> _exportCollections(
    BuildContext context,
    WidgetRef ref,
    List<CollectionPayment> payments,
  ) async {
    if (payments.isEmpty) return;
    final rows = [
      for (final p in payments)
        [
          p.receiptNumber,
          p.studentName,
          p.admissionNumber,
          p.classLabel,
          p.amount,
          p.mode,
          p.collectedAt,
          p.collectedBy,
          p.status.name,
        ],
    ];
    await ref.read(aksharaReportExportServiceProvider).shareGridCsv(
      filename: 'day_collections.csv',
      headers: const [
        'Receipt',
        'Student',
        'Admission No',
        'Class',
        'Amount',
        'Mode',
        'Collected At',
        'Collected By',
        'Status',
      ],
      rows: rows,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Day collections CSV ready (${rows.length} rows)')),
    );
  }

  /// FIN-5: batch-print receipts for the completed collections in view.
  Future<void> _printReceipts(
    BuildContext context,
    WidgetRef ref,
    List<CollectionPayment> payments,
  ) async {
    final completed = payments
        .where((p) => p.status == CollectionStatus.completed)
        .toList();
    if (completed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No completed receipts to print.')),
      );
      return;
    }
    final schoolName = ref.read(schoolDisplayNameProvider);
    final receipts = [
      for (final p in completed)
        ReceiptPdfData(
          receiptNumber: p.receiptNumber,
          schoolName: schoolName.isEmpty ? 'School' : schoolName,
          title: 'Fee Receipt',
          dateLabel: p.collectedAt,
          paymentMethod: p.mode,
          statusLabel: 'Paid',
          studentName: p.studentName,
          classLabel: p.classLabel,
          lineItems: [
            ReceiptPdfLineItem(
              label: 'Fee payment',
              amount:
                  int.tryParse(p.amount.replaceAll(RegExp(r'[^\d-]'), '')) ?? 0,
            ),
          ],
          totalAmount:
              int.tryParse(p.amount.replaceAll(RegExp(r'[^\d-]'), '')) ?? 0,
        ),
    ];
    final bytes = await ref
        .read(batchPrintReceiptsProvider.notifier)
        .execute(receipts: receipts);
    if (!context.mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not generate receipts.')),
      );
      return;
    }
    await const FinanceReceiptPdfService().printReceipt(bytes);
  }
}

/// FIN-D1 — day-close lock control. Shows the latest closed day (if any) and
/// offers Close-day / Reopen actions to finance managers.
class _DayCloseControl extends ConsumerWidget {
  const _DayCloseControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(financeDayCloseEntriesFutureProvider);
    final colors = context.colors;
    final text = context.aksharaText;

    final entries = entriesAsync.valueOrNull ?? const <DayCloseEntry>[];
    // Latest closed day (repository surfaces most-recent first).
    DayCloseEntry? latestClosed;
    for (final entry in entries) {
      if (entry.isClosed) {
        latestClosed = entry;
        break;
      }
    }

    final statusLabel = latestClosed == null
        ? 'No day closed yet'
        : 'Last closed day: ${latestClosed.closeDate}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Row(
          children: [
            Icon(Icons.lock_clock_outlined, color: colors.primary),
            const SizedBox(width: AksharaSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day-close lock', style: text.titleSmall),
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(statusLabel, style: text.bodySmall),
                ],
              ),
            ),
            AksharaManageAction(
              permission: Permission.manageFinance,
              child: Wrap(
                spacing: AksharaSpacing.s2,
                children: [
                  if (latestClosed != null)
                    OutlinedButton.icon(
                      key: QaTestKeys.financeReopenDayButton,
                      onPressed: () =>
                          reopenDay(context, ref, date: latestClosed!.closeDate),
                      icon: const Icon(Icons.lock_open_outlined, size: 18),
                      label: const Text('Reopen'),
                    ),
                  FilledButton.icon(
                    key: QaTestKeys.financeCloseDayButton,
                    onPressed: () => closeDay(context, ref),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Close day'),
                  ),
                ],
              ),
            ),
          ],
        ),
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
