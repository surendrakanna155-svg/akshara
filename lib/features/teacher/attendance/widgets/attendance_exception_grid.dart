import 'package:flutter/material.dart';

import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/feedback/akshara_haptics.dart';
import '../../../../theme/accessibility.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../attendance_models.dart';

/// P2-UX-2 §2.1 — the exception-first attendance surface. A dense grid of
/// student tiles so a whole class fits with minimal scrolling: mark everyone
/// present in one tap ("All present"), then tap ONLY the exceptions. A tap
/// cycles present → absent → late; a long-press opens the full mark picker
/// (incl. half-day / excused). Marking flows through the SAME workflow the row
/// used ([onMark] → updateStudentMark), so providers / draft / submit gate are
/// untouched — this is presentation only.
class AttendanceExceptionGrid extends StatelessWidget {
  const AttendanceExceptionGrid({
    super.key,
    required this.students,
    required this.enabled,
    required this.onMark,
    this.padding = EdgeInsets.zero,
  });

  final List<TeacherAttendanceStudent> students;
  final bool enabled;
  final void Function(String studentId, StudentAttendanceMark mark) onMark;
  final EdgeInsets padding;

  static StudentAttendanceMark cycle(StudentAttendanceMark mark) =>
      switch (mark) {
        StudentAttendanceMark.unmarked => StudentAttendanceMark.present,
        StudentAttendanceMark.present => StudentAttendanceMark.absent,
        StudentAttendanceMark.absent => StudentAttendanceMark.late,
        StudentAttendanceMark.late => StudentAttendanceMark.present,
        // Fold the rarer marks back into the fast cycle; the picker sets them.
        StudentAttendanceMark.halfDay => StudentAttendanceMark.present,
        StudentAttendanceMark.excused => StudentAttendanceMark.present,
      };

  @override
  Widget build(BuildContext context) {
    // P2-UX-4 (Polish §7): this is a dense grid with a fixed 68px cell — the one
    // place a text-scale clamp is allowed. Cap the inherited scale at 1.3× so a
    // very large system font stays legible without overflowing the cell (a no-op
    // at the default 1.0×; the roster still grows/scrolls normally).
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: AksharaAccessibility.clampDenseGridTextScale(mq.textScaler),
      ),
      child: GridView.builder(
        padding: padding,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 210,
          mainAxisExtent: 68,
          crossAxisSpacing: AksharaSpacing.s2,
          mainAxisSpacing: AksharaSpacing.s2,
        ),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          return _StudentExceptionTile(
            student: student,
            enabled: enabled,
            onCycle: () => onMark(student.id, cycle(student.mark)),
            onPick: (mark) => onMark(student.id, mark),
          );
        },
      ),
    );
  }
}

KpiAccent _toneFor(StudentAttendanceMark mark) => switch (mark) {
      StudentAttendanceMark.present => KpiAccent.success,
      StudentAttendanceMark.absent => KpiAccent.error,
      StudentAttendanceMark.late => KpiAccent.warning,
      StudentAttendanceMark.halfDay => KpiAccent.indigo,
      StudentAttendanceMark.excused => KpiAccent.tertiary,
      StudentAttendanceMark.unmarked => KpiAccent.neutral,
    };

class _StudentExceptionTile extends StatelessWidget {
  const _StudentExceptionTile({
    required this.student,
    required this.enabled,
    required this.onCycle,
    required this.onPick,
  });

  final TeacherAttendanceStudent student;
  final bool enabled;
  final VoidCallback onCycle;
  final ValueChanged<StudentAttendanceMark> onPick;

  bool get _isException =>
      student.mark != StudentAttendanceMark.present &&
      student.mark != StudentAttendanceMark.unmarked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final tone = _toneFor(student.mark).resolve(context);
    // Exceptions get a tinted fill + tone border so they pop out of a mostly
    // "present" roster; present / unmarked tiles stay calm.
    final background = _isException ? tone.container : colors.surface;
    final border = _isException ? tone.foreground : colors.outlineVariant;

    return Semantics(
      button: true,
      label: '${student.name}, roll ${student.rollNo}, ${student.mark.label}',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: InkWell(
          key: QaTestKeys.teacherAttendanceExceptionTile(student.id),
          onTap: enabled
              ? () {
                  AksharaHaptics.tick();
                  onCycle();
                }
              : null,
          onLongPress: enabled ? () => _showPicker(context) : null,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s3,
              vertical: AksharaSpacing.s2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AksharaSpacing.s3),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                _MarkBadge(mark: student.mark),
                const SizedBox(width: AksharaSpacing.s2),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: text.bodyMedium.copyWith(
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Roll ${student.rollNo} · ${student.mark.label}',
                        style: text.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<StudentAttendanceMark>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              child: Text(
                '${student.name} · Roll ${student.rollNo}',
                style: context.aksharaText.titleSmall,
              ),
            ),
            for (final mark in const [
              StudentAttendanceMark.present,
              StudentAttendanceMark.absent,
              StudentAttendanceMark.late,
              StudentAttendanceMark.halfDay,
              StudentAttendanceMark.excused,
            ])
              ListTile(
                key: QaTestKeys.teacherAttendancePickMark(student.id, mark.name),
                leading: _MarkBadge(mark: mark),
                title: Text(mark.label),
                selected: student.mark == mark,
                onTap: () => Navigator.of(context).pop(mark),
              ),
          ],
          ),
        ),
      ),
    );
    if (picked != null) {
      AksharaHaptics.tick();
      onPick(picked);
    }
  }
}

class _MarkBadge extends StatelessWidget {
  const _MarkBadge({required this.mark});

  final StudentAttendanceMark mark;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(mark).resolve(context);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.foreground,
        shape: BoxShape.circle,
      ),
      child: Text(
        mark.shortLabel,
        style: context.aksharaText.labelMedium.copyWith(
          // P2-UX-4: the badge fill is a semantic tone that is dark in the light
          // scheme but bright in the dark scheme — a hardcoded white letter fails
          // WCAG on the bright tones. Pick the letter colour by contrast.
          color: AksharaAccessibility.onColorFor(tone.foreground),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
