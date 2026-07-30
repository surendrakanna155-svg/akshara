import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_section_empty.dart';
import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../../admin/admin_layout.dart';
import '../../finance_models.dart';

/// Recent payments table for FN-01 dashboard.
class FinanceRecentPaymentsTable extends StatelessWidget {
  const FinanceRecentPaymentsTable({
    super.key,
    required this.payments,
  });

  final List<RecentPayment> payments;

  @override
  Widget build(BuildContext context) {
    // No payments is a real day-one state, not a rendering failure — an empty
    // table body under "Recent payments" reads as money gone missing.
    if (payments.isEmpty) {
      return const AksharaSectionEmpty(
        message: 'No payments collected yet. Receipts appear here as fees are '
            'paid.',
        icon: Icons.receipt_long_outlined,
      );
    }

    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final payment in payments) ...[
            _PaymentMobileCard(payment: payment),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Recent payments, ${payments.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('Student')),
            DataColumn(label: Text('Admission No.')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Mode')),
            DataColumn(label: Text('Receipt')),
            DataColumn(label: Text('Collected')),
            DataColumn(label: Text('Status')),
          ],
          rows: [
            for (final payment in payments)
              DataRow(
                cells: [
                  DataCell(Text(payment.studentName)),
                  DataCell(Text(payment.admissionNumber)),
                  DataCell(Text(payment.amount)),
                  DataCell(Text(payment.mode)),
                  DataCell(Text(payment.receiptNumber)),
                  DataCell(Text(payment.collectedAt)),
                  DataCell(_PaymentStatusChip(status: payment.status)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentStatusChip extends StatelessWidget {
  const _PaymentStatusChip({required this.status});

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

class _PaymentMobileCard extends StatelessWidget {
  const _PaymentMobileCard({required this.payment});

  final RecentPayment payment;

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
            Text(payment.studentName, style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              '${payment.amount} · ${payment.mode}',
              style: text.bodyMedium,
            ),
            Text(
              '${payment.receiptNumber} · ${payment.collectedAt}',
              style: text.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            _PaymentStatusChip(status: payment.status),
          ],
        ),
      ),
    );
  }
}
