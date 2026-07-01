import 'package:flutter/material.dart';

import '../../../../core/testing/qa_test_keys.dart';
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
    this.enabled = true,
  });

  final TeacherAttendanceStudent student;
  final ValueChanged<StudentAttendanceMark> onMarkChanged;
  final bool enabled;

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
                markKey: QaTestKeys.teacherAttendanceMarkChip(
                  student.id,
                  'present',
                ),
                label: 'P',
                selected: student.mark == StudentAttendanceMark.present,
                tone: KpiAccent.success,
                onTap: enabled
                    ? () => onMarkChanged(StudentAttendanceMark.present)
                    : null,
              ),
              const SizedBox(width: AksharaSpacing.s1),
              _MarkChip(
                markKey: QaTestKeys.teacherAttendanceMarkChip(
                  student.id,
                  'absent',
                ),
                label: 'A',
                selected: student.mark == StudentAttendanceMark.absent,
                tone: KpiAccent.error,
                onTap: enabled
                    ? () => onMarkChanged(StudentAttendanceMark.absent)
                    : null,
              ),
              const SizedBox(width: AksharaSpacing.s1),
              _MarkChip(
                markKey: QaTestKeys.teacherAttendanceMarkChip(
                  student.id,
                  'late',
                ),
                label: 'L',
                selected: student.mark == StudentAttendanceMark.late,
                tone: KpiAccent.warning,
                onTap: enabled
                    ? () => onMarkChanged(StudentAttendanceMark.late)
                    : null,
              ),
              const SizedBox(width: AksharaSpacing.s1),
              _MarkChip(
                markKey: QaTestKeys.teacherAttendanceMarkChip(
                  student.id,
                  'half_day',
                ),
                label: 'H',
                selected: student.mark == StudentAttendanceMark.halfDay,
                tone: KpiAccent.indigo,
                onTap: enabled
                    ? () => onMarkChanged(StudentAttendanceMark.halfDay)
                    : null,
              ),
              const SizedBox(width: AksharaSpacing.s1),
              _MarkChip(
                markKey: QaTestKeys.teacherAttendanceMarkChip(
                  student.id,
                  'excused',
                ),
                label: 'E',
                selected: student.mark == StudentAttendanceMark.excused,
                tone: KpiAccent.tertiary,
                onTap: enabled
                    ? () => onMarkChanged(StudentAttendanceMark.excused)
                    : null,
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
    required this.markKey,
    required this.label,
    required this.selected,
    required this.tone,
    required this.onTap,
  });

  final Key markKey;
  final String label;
  final bool selected;
  final KpiAccent tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        key: markKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AksharaSpacing.s2),
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: AksharaStatusChip(
          label: label,
          tone: selected ? tone : KpiAccent.neutral,
          size: AksharaStatusChipSize.compact,
        ),
        ),
      ),
    );
  }
}
