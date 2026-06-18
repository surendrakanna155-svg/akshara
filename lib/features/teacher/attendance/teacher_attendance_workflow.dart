import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/forms/akshara_form_field.dart';
import '../../../shared/widgets/akshara_dialog.dart';
import '../../../shared/widgets/akshara_motion.dart';
import '../teacher_mutations_provider.dart';
import '../teacher_requests.dart';
import 'attendance_models.dart';

Future<void> showAttendanceCorrectionDialog(
  BuildContext context,
  WidgetRef ref, {
  required TeacherAttendanceData data,
}) async {
  if (data.students.isEmpty) return;

  final selectedClass = data.classes.firstWhere(
    (item) => item.id == data.selectedClassId,
    orElse: () => data.classes.first,
  );
  final parts = selectedClass.label.split('-');
  final classLabel = parts.isNotEmpty ? parts.first : selectedClass.label;
  final section = parts.length > 1 ? parts.last : 'A';

  TeacherAttendanceStudent selectedStudent = data.students.first;
  String fromMark = selectedStudent.mark.label;
  String toMark = StudentAttendanceMark.present.label;
  final reasonController = TextEditingController(
    text: 'Biometric sync error — student was present',
  );
  final dateController = TextEditingController(text: '12 Jun 2026');

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AksharaAlertDialog(
        title: 'Request attendance correction',
        icon: Icons.edit_calendar_outlined,
        scrollable: true,
        content: AksharaDialogFormBody(
          children: [
            DropdownButtonFormField<TeacherAttendanceStudent>(
              initialValue: selectedStudent,
              decoration: const InputDecoration(labelText: 'Student'),
              items: [
                for (final student in data.students)
                  DropdownMenuItem(
                    value: student,
                    child: Text('${student.rollNo} · ${student.name}'),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedStudent = value;
                  fromMark = value.mark.label;
                });
              },
            ),
            AksharaFormField(
              label: 'Attendance date',
              controller: dateController,
              required: true,
            ),
            DropdownButtonFormField<String>(
              initialValue: fromMark,
              decoration: const InputDecoration(labelText: 'Recorded mark'),
              items: StudentAttendanceMark.values
                  .where((mark) => mark != StudentAttendanceMark.unmarked)
                  .map(
                    (mark) => DropdownMenuItem(
                      value: mark.label,
                      child: Text(mark.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => fromMark = value);
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: toMark,
              decoration: const InputDecoration(labelText: 'Corrected mark'),
              items: StudentAttendanceMark.values
                  .where((mark) => mark != StudentAttendanceMark.unmarked)
                  .map(
                    (mark) => DropdownMenuItem(
                      value: mark.label,
                      child: Text(mark.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => toMark = value);
              },
            ),
            AksharaFormField(
              label: 'Reason',
              controller: reasonController,
              required: true,
            ),
          ],
        ),
        actions: [
          AksharaDialogActions(
            cancelLabel: 'Cancel',
            confirmLabel: 'Submit for approval',
            confirmKey: QaTestKeys.teacherAttendanceCorrectionSubmitButton,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final result = await ref
        .read(submitAttendanceCorrectionProvider.notifier)
        .execute(
          TeacherAttendanceCorrectionRequest(
            sisStudentId: selectedStudent.id,
            studentName: selectedStudent.name,
            classLabel: classLabel,
            section: section,
            dateLabel: dateController.text.trim(),
            fromMark: fromMark,
            toMark: toMark,
            reason: reasonController.text.trim(),
            presentDelta: toMark == StudentAttendanceMark.present.label ? 1 : 0,
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Correction could not be submitted'
              : 'Correction submitted for principal approval (${result.approvalId})',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error')),
    );
  }
}
