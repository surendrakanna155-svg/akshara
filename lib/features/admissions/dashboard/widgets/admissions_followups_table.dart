import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';
import '../../../admin/admin_layout.dart';

/// Follow-ups due today table (desktop) with mobile card fallback.
class AdmissionsFollowupsTable extends StatelessWidget {
  const AdmissionsFollowupsTable({
    super.key,
    required this.followUps,
    this.onAction,
  });

  final List<AdmissionsFollowUp> followUps;
  final void Function(AdmissionsFollowUp item)? onAction;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final item in followUps) ...[
            _FollowUpMobileCard(item: item, onAction: onAction),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Follow-ups due today, ${followUps.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('Due')),
            DataColumn(label: Text('Lead')),
            DataColumn(label: Text('Task')),
            DataColumn(label: Text('Counselor')),
            DataColumn(label: Text('Priority')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final item in followUps)
              DataRow(
                cells: [
                  DataCell(Text(item.dueLabel)),
                  DataCell(Text(item.leadName)),
                  DataCell(Text(item.task)),
                  DataCell(Text(item.counselor)),
                  DataCell(_PriorityChip(priority: item.priority)),
                  DataCell(_StatusChip(status: item.status)),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.more_horiz),
                      tooltip: 'Actions',
                      onPressed: onAction == null
                          ? null
                          : () => onAction!(item),
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

class _FollowUpMobileCard extends StatelessWidget {
  const _FollowUpMobileCard({required this.item, this.onAction});

  final AdmissionsFollowUp item;
  final void Function(AdmissionsFollowUp item)? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      label: 'Follow-up for ${item.leadName}, due ${item.dueLabel}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    item.dueLabel,
                    style: text.labelLarge.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  _PriorityChip(priority: item.priority),
                ],
              ),
              Text(item.leadName, style: text.bodyMedium),
              Text(
                item.task,
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Row(
                children: [
                  Text(
                    item.counselor,
                    style: text.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  _StatusChip(status: item.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final FollowUpPriority priority;

  @override
  Widget build(BuildContext context) {
    final tone = switch (priority) {
      FollowUpPriority.high => KpiAccent.error,
      FollowUpPriority.medium => KpiAccent.warning,
      FollowUpPriority.low => KpiAccent.neutral,
    };

    return AksharaStatusChip(
      label: priority.name[0].toUpperCase() + priority.name.substring(1),
      tone: tone,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final FollowUpStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      FollowUpStatus.pending => KpiAccent.primary,
      FollowUpStatus.completed => KpiAccent.success,
      FollowUpStatus.overdue => KpiAccent.error,
    };

    return AksharaStatusChip(
      label: status.name[0].toUpperCase() + status.name.substring(1),
      tone: tone,
    );
  }
}
