import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../attendance_models.dart';

/// Single student attendance row with mark chips.
class StudentAttendanceRow extends StatelessWidget {
  const StudentAttendanceRow({
    super.key,
    required this.student,
    required this.onMarkChanged,
  });

  final TeacherAttendanceStudent student;
  final ValueChanged<StudentAttendanceMark> onMarkChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      label: '${student.name}, roll ${student.rollNo}, ${student.mark.label}',
      child: Material(
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s4,
            vertical: AksharaSpacing.s2,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  student.rollNo,
                  style: text.labelMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  student.name,
                  style: text.bodyMedium.copyWith(color: colors.onSurface),
                ),
              ),
              _MarkChip(
                label: 'P',
                selected: student.mark == StudentAttendanceMark.present,
                tone: KpiAccent.success,
                onTap: () => onMarkChanged(StudentAttendanceMark.present),
              ),
              const SizedBox(width: AksharaSpacing.s1),
              _MarkChip(
                label: 'A',
                selected: student.mark == StudentAttendanceMark.absent,
                tone: KpiAccent.error,
                onTap: () => onMarkChanged(StudentAttendanceMark.absent),
              ),
              const SizedBox(width: AksharaSpacing.s1),
              _MarkChip(
                label: 'L',
                selected: student.mark == StudentAttendanceMark.late,
                tone: KpiAccent.warning,
                onTap: () => onMarkChanged(StudentAttendanceMark.late),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkChip extends StatelessWidget {
  const _MarkChip({
    required this.label,
    required this.selected,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final KpiAccent tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AksharaSpacing.s2),
        child: AksharaStatusChip(
          label: label,
          tone: selected ? tone : KpiAccent.neutral,
          size: AksharaStatusChipSize.compact,
        ),
      ),
    );
  }
}
