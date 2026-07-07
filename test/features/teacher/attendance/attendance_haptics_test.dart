import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/attendance/widgets/student_attendance_row.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// P2-UX-2 §2.1 — a haptic tick fires on every attendance mark change (physical
/// feedback on the highest-frequency daily task) without altering the write.
void main() {
  testWidgets('tapping a mark chip fires a selection tick AND the mark change',
      (tester) async {
    final haptics = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String?);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    StudentAttendanceMark? marked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: StudentAttendanceRow(
            student: const TeacherAttendanceStudent(
              id: 's1',
              name: 'Asha K',
              rollNo: '1',
              mark: StudentAttendanceMark.unmarked,
            ),
            onMarkChanged: (m) => marked = m,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('A')); // Absent chip
    await tester.pump();

    expect(marked, StudentAttendanceMark.absent,
        reason: 'the mark write must still happen');
    expect(haptics, contains('HapticFeedbackType.selectionClick'),
        reason: 'a selection tick fires on the state change');
  });

  testWidgets('disabled chips fire no haptic and no mark change', (tester) async {
    final haptics = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String?);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: StudentAttendanceRow(
            enabled: false,
            student: const TeacherAttendanceStudent(
              id: 's1',
              name: 'Asha K',
              rollNo: '1',
              mark: StudentAttendanceMark.present,
            ),
            onMarkChanged: (_) => changed = true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('A'));
    await tester.pump();

    expect(changed, isFalse);
    expect(haptics, isEmpty);
  });
}
