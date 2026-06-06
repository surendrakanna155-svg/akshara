import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';
import '../../../admin/admin_layout.dart';

/// Follow-up history list/table for AD-04.
class AdmissionsLeadFollowUpHistory extends StatelessWidget {
  const AdmissionsLeadFollowUpHistory({
    super.key,
    required this.records,
  });

  final List<LeadFollowUpRecord> records;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final record in records) ...[
            _FollowUpCard(record: record),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Follow-up history, ${records.length} records',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          columns: const [
            DataColumn(label: Text('Scheduled')),
            DataColumn(label: Text('Completed')),
            DataColumn(label: Text('Task')),
            DataColumn(label: Text('Counselor')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Outcome')),
          ],
          rows: [
            for (final record in records)
              DataRow(
                cells: [
                  DataCell(Text(record.scheduledLabel)),
                  DataCell(Text(record.completedLabel)),
                  DataCell(Text(record.task)),
                  DataCell(Text(record.counselor)),
                  DataCell(_StatusChip(status: record.status)),
                  DataCell(Text(record.outcome)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({required this.record});

  final LeadFollowUpRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Material(
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
                  record.scheduledLabel,
                  style: text.labelLarge.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _StatusChip(status: record.status),
              ],
            ),
            Text(record.task, style: text.bodyMedium),
            Text(
              '${record.counselor} · ${record.outcome}',
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
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
