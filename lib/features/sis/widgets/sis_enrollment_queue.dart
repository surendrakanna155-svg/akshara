import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../../admissions/admissions_models.dart';
import '../sis_models.dart';

/// Admissions conversion queue for SIS-01 dashboard.
class SisEnrollmentQueue extends StatelessWidget {
  const SisEnrollmentQueue({
    super.key,
    required this.items,
    this.compact = false,
    this.onConvert,
  });

  final List<SisEnrollmentQueueItem> items;
  final bool compact;
  final void Function(SisEnrollmentQueueItem item)? onConvert;

  @override
  Widget build(BuildContext context) {
    final pending = items
        .where((i) => i.effectiveStatus == EnrollmentConversionStatus.pending)
        .toList();

    if (pending.isEmpty) {
      return Semantics(
        label: 'No pending admissions conversions',
        child: Text(
          'No enrollments awaiting SIS conversion.',
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
            _EnrollmentMobileCard(item: item, onConvert: onConvert),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Admissions conversion queue, ${displayItems.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: [
            const DataColumn(label: Text('Student')),
            const DataColumn(label: Text('Application')),
            const DataColumn(label: Text('Class')),
            if (!compact) const DataColumn(label: Text('Guardian')),
            const DataColumn(label: Text('Submitted')),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final item in displayItems)
              DataRow(
                cells: [
                  DataCell(Text(item.enrollment.studentName)),
                  DataCell(Text(item.enrollment.applicationId)),
                  DataCell(
                    Text(
                      'Class ${item.enrollment.seekingClass}-${item.enrollment.section}',
                    ),
                  ),
                  if (!compact) DataCell(Text(item.enrollment.guardianName)),
                  DataCell(Text(item.enrollment.submittedAt)),
                  DataCell(_ConversionStatusChip(status: item.effectiveStatus)),
                  DataCell(
                    TextButton(
                      onPressed: onConvert == null
                          ? () => context.go(RouteNames.sisAdmissionsConversion)
                          : () => onConvert!(item),
                      child: const Text('Convert'),
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

class _ConversionStatusChip extends StatelessWidget {
  const _ConversionStatusChip({required this.status});

  final EnrollmentConversionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      EnrollmentConversionStatus.pending => ('Pending', KpiAccent.warning),
      EnrollmentConversionStatus.converted => ('Converted', KpiAccent.success),
      EnrollmentConversionStatus.failed => ('Failed', KpiAccent.error),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _EnrollmentMobileCard extends StatelessWidget {
  const _EnrollmentMobileCard({required this.item, this.onConvert});

  final SisEnrollmentQueueItem item;
  final void Function(SisEnrollmentQueueItem item)? onConvert;

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
            Text(item.enrollment.studentName, style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              '${item.enrollment.applicationId} · Class ${item.enrollment.seekingClass}',
              style: text.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            _ConversionStatusChip(status: item.effectiveStatus),
            const SizedBox(height: AksharaSpacing.s3),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onConvert == null
                    ? () => context.go(RouteNames.sisAdmissionsConversion)
                    : () => onConvert!(item),
                child: const Text('Convert to SIS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
