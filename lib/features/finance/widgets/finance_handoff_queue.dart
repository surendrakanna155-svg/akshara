import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../../admissions/admissions_models.dart';
import '../finance_models.dart';

/// Admissions handoff queue table for FN-01 and FN-04.
class FinanceHandoffQueue extends StatelessWidget {
  const FinanceHandoffQueue({
    super.key,
    required this.items,
    this.onAssign,
    this.compact = false,
  });

  final List<FinanceHandoffQueueItem> items;
  final void Function(FinanceHandoffQueueItem item)? onAssign;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pending = items
        .where(
          (i) =>
              i.effectiveStatus == FeeHandoffStatus.pending ||
              i.effectiveStatus == FeeHandoffStatus.sentToFinance,
        )
        .toList();

    if (pending.isEmpty) {
      return Semantics(
        label: 'No pending admissions handoffs',
        child: Text(
          'No students awaiting fee assignment.',
          style: context.aksharaText.bodyMedium.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    final displayItems = compact ? pending.take(3).toList() : pending;

    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final item in displayItems) ...[
            _HandoffMobileCard(item: item, onAssign: onAssign),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Admissions handoff queue, ${displayItems.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: [
            const DataColumn(label: Text('Student')),
            const DataColumn(label: Text('Class')),
            const DataColumn(label: Text('Admission No.')),
            if (!compact) const DataColumn(label: Text('Application')),
            const DataColumn(label: Text('Add-ons')),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final item in displayItems)
              DataRow(
                key: QaTestKeys.financeHandoffQueueRow(item.handoff.studentName),
                cells: [
                  DataCell(Text(item.handoff.studentName)),
                  DataCell(Text(item.handoff.classLabel)),
                  DataCell(Text(item.handoff.admissionNumber)),
                  if (!compact) DataCell(Text(item.handoff.applicationId)),
                  DataCell(Text(_addOnsLabel(item.handoff))),
                  DataCell(_HandoffStatusChip(status: item.effectiveStatus)),
                  DataCell(
                    TextButton(
                      onPressed: onAssign == null
                          ? () => context.go(RouteNames.financeFeeAssignment)
                          : () => onAssign!(item),
                      child: Text(
                        item.effectiveStatus == FeeHandoffStatus.completed
                            ? 'View'
                            : 'Assign',
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _addOnsLabel(ApprovedStudentHandoff handoff) {
    final parts = <String>[];
    if (handoff.needsTransport) parts.add('Transport');
    if (handoff.needsHostel) parts.add('Hostel');
    return parts.isEmpty ? '—' : parts.join(', ');
  }
}

class _HandoffStatusChip extends StatelessWidget {
  const _HandoffStatusChip({required this.status});

  final FeeHandoffStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      FeeHandoffStatus.pending => ('Pending', KpiAccent.warning),
      FeeHandoffStatus.sentToFinance => ('Sent to Finance', KpiAccent.primary),
      FeeHandoffStatus.completed => ('Completed', KpiAccent.success),
      FeeHandoffStatus.failed => ('Failed', KpiAccent.error),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _HandoffMobileCard extends StatelessWidget {
  const _HandoffMobileCard({required this.item, this.onAssign});

  final FinanceHandoffQueueItem item;
  final void Function(FinanceHandoffQueueItem item)? onAssign;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Card(
      key: QaTestKeys.financeHandoffQueueRow(item.handoff.studentName),
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
            Text(item.handoff.studentName, style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              'Class ${item.handoff.classLabel} · ${item.handoff.admissionNumber}',
              style: text.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            _HandoffStatusChip(status: item.effectiveStatus),
            const SizedBox(height: AksharaSpacing.s3),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAssign == null
                    ? () => context.go(RouteNames.financeFeeAssignment)
                    : () => onAssign!(item),
                child: const Text('Assign fees'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
