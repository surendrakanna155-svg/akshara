import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/approvals/approval_models.dart';
import '../../../../core/approvals/approval_status.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../core/approvals/approval_permissions.dart';
import '../../../../shared/widgets/akshara_approve_action.dart';
import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../../admin/admin_layout.dart';
import '../approval_center_actions.dart';
import '../approval_center_provider.dart';
import '../approval_date_format.dart';
import 'approval_detail_panel.dart';

/// Desktop table and mobile cards for the unified approval queue.
class ApprovalQueueTable extends ConsumerWidget {
  const ApprovalQueueTable({
    super.key,
    required this.items,
  });

  final List<ApprovalRequest> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final item in items) ...[
            _ApprovalMobileCard(item: item),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Approval queue table, ${items.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 88,
            columns: const [
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Requester')),
              DataColumn(label: Text('Submitted')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  selected: ref.watch(approvalCenterSelectedIdProvider) ==
                      item.id,
                  onSelectChanged: (_) => ref
                      .read(approvalCenterSelectedIdProvider.notifier)
                      .state = item.id,
                  cells: [
                    DataCell(Text(item.title)),
                    DataCell(Text(item.type.label)),
                    DataCell(Text(item.requesterName)),
                    DataCell(Text(_formatDate(item.createdAt))),
                    DataCell(_StatusChip(status: item.status)),
                    DataCell(_ApprovalActions(item: item)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) => formatApprovalDate(value);
}

class _ApprovalMobileCard extends ConsumerWidget {
  const _ApprovalMobileCard({required this.item});

  final ApprovalRequest item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Approval: ${item.title}',
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: () => _showMobileDetail(context, ref, item),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: text.titleSmall),
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  '${item.requesterName} · ${item.type.label} · ${_formatDate(item.createdAt)}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AksharaSpacing.s3),
                _StatusChip(status: item.status),
                if (item.status == ApprovalStatus.pending) ...[
                  const SizedBox(height: AksharaSpacing.s3),
                  _ApprovalActions(item: item),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMobileDetail(
    BuildContext context,
    WidgetRef ref,
    ApprovalRequest item,
  ) {
    ref.read(approvalCenterSelectedIdProvider.notifier).state = item.id;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: ApprovalDetailPanel(
            request: item,
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) => formatApprovalDate(value);
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      ApprovalStatus.pending => ('Pending', KpiAccent.warning),
      ApprovalStatus.approved => ('Approved', KpiAccent.success),
      ApprovalStatus.rejected => ('Rejected', KpiAccent.error),
      ApprovalStatus.cancelled => ('Cancelled', KpiAccent.neutral),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _ApprovalActions extends ConsumerWidget {
  const _ApprovalActions({required this.item});

  final ApprovalRequest item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.status != ApprovalStatus.pending) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Approval actions for ${item.title}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AksharaApproveAction(
            permission: approvalPermissionForType(item.type),
            child: FilledButton(
              key: QaTestKeys.approvalApproveButton(item.id),
              onPressed: () => approveApprovalRequest(context, ref, item),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Approve'),
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          AksharaApproveAction(
            permission: approvalPermissionForType(item.type),
            child: OutlinedButton(
              key: QaTestKeys.approvalRejectButton(item.id),
              onPressed: () => rejectApprovalRequest(context, ref, item),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Reject'),
            ),
          ),
        ],
      ),
    );
  }
}
