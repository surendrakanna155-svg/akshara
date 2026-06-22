import 'package:flutter/material.dart';

import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../../admin/admin_layout.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_application_status_chip.dart';

/// Pending approvals queue table (AD-07).
class AdmissionsApprovalQueueTable extends StatelessWidget {
  const AdmissionsApprovalQueueTable({
    super.key,
    required this.items,
    this.selectedId,
    this.onSelect,
  });

  final List<ApprovalQueueItem> items;
  final String? selectedId;
  final ValueChanged<ApprovalQueueItem>? onSelect;

  static const _columns = [
    DataColumn(label: Text('Student')),
    DataColumn(label: Text('Class')),
    DataColumn(label: Text('Counselor')),
    DataColumn(label: Text('Docs')),
    DataColumn(label: Text('AI Score')),
    DataColumn(label: Text('Status')),
    DataColumn(label: Text('Submitted')),
  ];

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final item in items) ...[
            _ApprovalMobileCard(
              item: item,
              selected: item.id == selectedId,
              onTap: onSelect == null ? null : () => onSelect!(item),
            ),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return AksharaVirtualizedDataTable(
      columns: _columns,
      rowCount: items.length,
      dataRowMinHeight: 56,
      semanticLabel: 'Approval queue, ${items.length} applications',
      rowBuilder: (index) => _buildRow(context, items[index]),
    );
  }

  DataRow _buildRow(BuildContext context, ApprovalQueueItem item) {
    return DataRow(
      key: QaTestKeys.admissionsApprovalQueueRow(item.studentName),
      selected: item.id == selectedId,
      onSelectChanged: onSelect == null ? null : (_) => onSelect!(item),
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.studentName),
              Text(
                item.applicationId,
                style: context.aksharaText.bodySmall.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(item.classLabel)),
        DataCell(Text(item.counselor)),
        DataCell(Text('${item.documentsComplete}/${item.documentsTotal}')),
        DataCell(Text('${item.aiScore}')),
        DataCell(_DecisionChip(decision: item.decision)),
        DataCell(Text(item.submittedLabel)),
      ],
    );
  }
}

class _ApprovalMobileCard extends StatelessWidget {
  const _ApprovalMobileCard({
    required this.item,
    required this.selected,
    this.onTap,
  });

  final ApprovalQueueItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Material(
      key: QaTestKeys.admissionsApprovalQueueRow(item.studentName),
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.25)
          : colors.surface,
      borderRadius: BorderRadius.circular(AksharaSpacing.s3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.studentName,
                      style: text.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _DecisionChip(decision: item.decision),
                ],
              ),
              Text(
                '${item.applicationId} · Class ${item.classLabel}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              Text(
                'Docs ${item.documentsComplete}/${item.documentsTotal} · AI ${item.aiScore}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecisionChip extends StatelessWidget {
  const _DecisionChip({required this.decision});

  final ApprovalDecision decision;

  @override
  Widget build(BuildContext context) {
    final status = switch (decision) {
      ApprovalDecision.pending => ApplicationStatus.underReview,
      ApprovalDecision.approved => ApplicationStatus.approved,
      ApprovalDecision.rejected => ApplicationStatus.rejected,
    };
    return AdmissionsApplicationStatusChip(status: status);
  }
}
