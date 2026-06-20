import 'package:flutter/material.dart';

import '../../core/teaching/teacher_assignment_registry.dart';
import '../../core/timetable/class_teacher_assignments.dart';
import '../../core/timetable/timetable_generation_inputs.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Set one class teacher per section. The class teacher owns period 1 (where
/// attendance is taken), so the timetable generator reserves that slot for them.
class ClassTeacherAssignmentScreen extends StatefulWidget {
  const ClassTeacherAssignmentScreen({super.key});

  @override
  State<ClassTeacherAssignmentScreen> createState() =>
      _ClassTeacherAssignmentScreenState();
}

class _ClassTeacherAssignmentScreenState
    extends State<ClassTeacherAssignmentScreen> {
  // Teachers that can be picked as a class teacher.
  static const _teachers = TeacherAssignmentRegistry.assignments;

  String _nameFor(String teacherId) {
    for (final t in _teachers) {
      if (t.teacherId == teacherId) return t.teacherName;
    }
    return teacherId;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final store = ClassTeacherAssignmentStore.instance;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      appBar: AppBar(title: const Text('Class teachers')),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Material(
            color: colors.surfaceContainerHighest,
            borderRadius: AksharaRadius.card,
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s3),
              child: Text(
                'The class teacher takes attendance in the first period. Set one '
                'class teacher for each section — the timetable keeps period 1 '
                'free for them.',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Sections', fixedHeight: false),
          const SizedBox(height: AksharaSpacing.s2),
          for (final section in mockTimetableSections) ...[
            _SectionRow(
              classLabel: section.classLabel,
              currentTeacherId: store.teacherFor(section.classLabel),
              currentTeacherName: store.teacherFor(section.classLabel) == null
                  ? null
                  : _nameFor(store.teacherFor(section.classLabel)!),
              teachers: _teachers,
              onChanged: (teacherId) {
                setState(() {
                  if (teacherId == null) {
                    store.clear(section.classLabel);
                  } else {
                    store.assign(
                        classLabel: section.classLabel, teacherId: teacherId);
                  }
                });
              },
            ),
            const SizedBox(height: AksharaSpacing.s2),
          ],
          const SizedBox(height: AksharaSpacing.s3),
          Text(
            'After changing class teachers, open Timetable Automation and press '
            'Generate to rebuild the schedule.',
            style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.classLabel,
    required this.currentTeacherId,
    required this.currentTeacherName,
    required this.teachers,
    required this.onChanged,
  });

  final String classLabel;
  final String? currentTeacherId;
  final String? currentTeacherName;
  final List<TeacherAssignmentRecord> teachers;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AksharaRadius.card,
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Class $classLabel', style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    currentTeacherName == null
                        ? 'No class teacher set'
                        : 'Class teacher: $currentTeacherName',
                    style:
                        text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            DropdownButton<String?>(
              value: currentTeacherId,
              hint: const Text('Choose'),
              onChanged: onChanged,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Not set'),
                ),
                for (final t in teachers)
                  DropdownMenuItem<String?>(
                    value: t.teacherId,
                    child: Text(t.teacherName),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
