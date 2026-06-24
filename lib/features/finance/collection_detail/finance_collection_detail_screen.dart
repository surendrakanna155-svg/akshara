import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_manage_action.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../finance_workflow_actions.dart';
import '../widgets/finance_kpi_row.dart';
import '../widgets/finance_module_scaffold.dart';
import 'finance_collection_detail_provider.dart';

/// FN-06 — Collection detail for a single payment.
class FinanceCollectionDetailScreen extends ConsumerWidget {
  const FinanceCollectionDetailScreen({
    super.key,
    required this.collectionId,
  });

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState =
        ref.watch(financeCollectionDetailViewStateProvider(collectionId));

    return FinanceModuleScaffold(
      screen: FinanceScreen.collectionDetail,
      showFilterBar: false,
      body: FinanceAsyncBody<CollectionDetail?>(
        state: viewState,
        loadingLabel: 'Loading collection detail',
        emptyMessage: 'Collection record not found.',
        emptyIcon: Icons.receipt_long_outlined,
        onRetry: () => retryFinanceFuture(
          ref,
          financeCollectionDetailFutureProvider(collectionId),
        ),
        builder: (detail) => _buildDetailContent(context, ref, detail!),
      ),
    );
  }

  Widget _buildDetailContent(
    BuildContext context,
    WidgetRef ref,
    CollectionDetail detail,
  ) {
    final payment = detail.payment;
    final useCards = AdminLayout.useCardLayout(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AksharaSectionHeader(title: payment.receiptNumber),
        Text(
          '${payment.studentName} · ${payment.admissionNumber} · Class ${payment.classLabel}',
          style: context.aksharaText.bodyMedium,
        ),
        const SizedBox(height: AksharaSpacing.s4),
        FinanceKpiRow(
          desktopColumns: 4,
          cardHeight: 100,
          kpis: detail.summaryKpis,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Payment timeline'),
        const SizedBox(height: AksharaSpacing.s3),
        if (useCards)
          Column(
            children: [
              for (final entry in detail.paymentTimeline) ...[
                _TimelineMobileCard(entry: entry),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          _PaymentTimelineTable(entries: detail.paymentTimeline),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Installment history'),
        const SizedBox(height: AksharaSpacing.s3),
        if (useCards)
          Column(
            children: [
              for (final installment in detail.installmentHistory) ...[
                _InstallmentMobileCard(installment: installment),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          _InstallmentHistoryTable(installments: detail.installmentHistory),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Receipt links'),
        const SizedBox(height: AksharaSpacing.s3),
        Semantics(
          container: true,
          label: 'Related receipt links, ${detail.receiptLinks.length} items',
          child: Column(
            children: [
              for (final link in detail.receiptLinks) ...[
                _ReceiptLinkTile(link: link),
                const SizedBox(height: AksharaSpacing.s2),
              ],
            ],
          ),
        ),
        const SizedBox(height: AksharaSpacing.s6),
        if (payment.status != CollectionStatus.refunded)
          AksharaManageAction(
            permission: Permission.manageFinance,
            child: OutlinedButton.icon(
              key: QaTestKeys.financeCancelCollectionButton(collectionId),
              onPressed: () => executeCancelCollection(
                context,
                ref,
                collectionId: collectionId,
                receiptNumber: payment.receiptNumber,
              ),
              icon: const Icon(Icons.undo_outlined),
              label: const Text('Cancel collection'),
            ),
          ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: detail.aiInsight,
          actionLabel: 'View fee account',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI collection insight',
          onAction: () => context.go(RouteNames.financeStudentAccounts),
        ),
      ],
    );
  }
}

class _PaymentTimelineTable extends StatelessWidget {
  const _PaymentTimelineTable({required this.entries});

  final List<PaymentTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Payment timeline, ${entries.length} entries',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('Label')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Mode')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Status')),
          ],
          rows: [
            for (final entry in entries)
              DataRow(
                cells: [
                  DataCell(Text(entry.label)),
                  DataCell(Text(entry.amount)),
                  DataCell(Text(entry.mode)),
                  DataCell(Text(entry.timestamp)),
                  DataCell(_CollectionStatusChip(status: entry.status)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _InstallmentHistoryTable extends StatelessWidget {
  const _InstallmentHistoryTable({required this.installments});

  final List<InstallmentHistoryEntry> installments;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Installment history, ${installments.length} terms',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('Term')),
            DataColumn(label: Text('Due date')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Paid')),
            DataColumn(label: Text('Status')),
          ],
          rows: [
            for (final installment in installments)
              DataRow(
                cells: [
                  DataCell(Text(installment.termLabel)),
                  DataCell(Text(installment.dueDate)),
                  DataCell(Text(installment.amount)),
                  DataCell(Text(installment.paidAmount)),
                  DataCell(_CollectionStatusChip(status: installment.status)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineMobileCard extends StatelessWidget {
  const _TimelineMobileCard({required this.entry});

  final PaymentTimelineEntry entry;

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
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.label, style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              '${entry.amount} · ${entry.mode} · ${entry.timestamp}',
              style: text.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            _CollectionStatusChip(status: entry.status),
          ],
        ),
      ),
    );
  }
}

class _InstallmentMobileCard extends StatelessWidget {
  const _InstallmentMobileCard({required this.installment});

  final InstallmentHistoryEntry installment;

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
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(installment.termLabel, style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              'Due ${installment.dueDate} · ${installment.amount}',
              style: text.bodySmall,
            ),
            Text('Paid ${installment.paidAmount}', style: text.bodySmall),
            const SizedBox(height: AksharaSpacing.s2),
            _CollectionStatusChip(status: installment.status),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLinkTile extends StatelessWidget {
  const _ReceiptLinkTile({required this.link});

  final ReceiptLink link;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    // Receipt detail is display-only on the admin screen: the receipt's
    // `parentReceiptRoute` lives in the parent shell, so navigating there from
    // admin would be bounced by the cross-shell guard. Presented as a static
    // labeled row (no fake tap affordance) until an admin receipt view exists.
    return Semantics(
      label: 'Receipt ${link.receiptNumber}, ${link.amount}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: InkWell(
          onTap: null,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Row(
              children: [
                Icon(Icons.receipt_outlined, color: colors.primary),
                const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(link.receiptNumber, style: text.titleSmall),
                      Text(
                        '${link.amount} · ${link.dateLabel}',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, size: 18, color: colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
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
