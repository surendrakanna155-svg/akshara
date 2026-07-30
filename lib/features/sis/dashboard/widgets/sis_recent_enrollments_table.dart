import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_section_empty.dart';
import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../../admin/admin_layout.dart';
import '../../sis_models.dart';

class SisRecentEnrollmentsTable extends StatelessWidget {
  const SisRecentEnrollmentsTable({
    super.key,
    required this.enrollments,
  });

  final List<RecentEnrollment> enrollments;

  @override
  Widget build(BuildContext context) {
    // Day one a school has no students by definition, so this is the section
    // most likely to be a blank hole under a header on a first login. Say what
    // is happening instead of rendering nothing.
    if (enrollments.isEmpty) {
      return const AksharaSectionEmpty(
        message: 'No students enrolled yet. New admissions appear here as they '
            'join.',
        icon: Icons.school_outlined,
      );
    }

    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final item in enrollments) ...[
            _EnrollmentMobileCard(item: item),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Recent enrollments, ${enrollments.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('Student')),
            DataColumn(label: Text('Admission No.')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Section')),
            DataColumn(label: Text('Enrolled')),
            DataColumn(label: Text('Status')),
          ],
          rows: [
            for (final item in enrollments)
              DataRow(
                cells: [
                  DataCell(Text(item.studentName)),
                  DataCell(Text(item.admissionNumber)),
                  DataCell(Text(item.classLabel)),
                  DataCell(Text(item.section)),
                  DataCell(Text(item.enrolledAt)),
                  DataCell(_StatusChip(status: item.status)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SisStudentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      SisStudentStatus.active => ('Active', KpiAccent.success),
      SisStudentStatus.prospect => ('Prospect', KpiAccent.warning),
      SisStudentStatus.transferred => ('Transferred', KpiAccent.primary),
      SisStudentStatus.exited => ('Exited', KpiAccent.neutral),
      SisStudentStatus.alumni => ('Alumni', KpiAccent.neutral),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _EnrollmentMobileCard extends StatelessWidget {
  const _EnrollmentMobileCard({required this.item});

  final RecentEnrollment item;

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
            Text(item.studentName, style: text.titleSmall),
            Text(
              '${item.admissionNumber} · Class ${item.classLabel}-${item.section}',
              style: text.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            _StatusChip(status: item.status),
          ],
        ),
      ),
    );
  }
}
