import 'package:akshara_erp/core/reliability/reliability_providers.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_provider.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

/// F-080 (P1) — destructive-bulk safety. "All present"/"All absent" must not
/// silently wipe an in-progress roster (and let autosave persist the wiped
/// state over the recoverable draft). Two guards:
///   1. Confirm BEFORE overwriting rows that are already marked (a blank roster
///      applies directly — no needless friction).
///   2. A SnackBar Undo restores the EXACT prior roster, and the debounced
///      autosave then persists the restored roster — never the wiped one.

const _classId = 'class-8a-p1';
const _draftKey = 'attendance:$_classId';

const _classes = [
  TeacherAttendanceClass(
    id: _classId,
    label: 'Class 8-A',
    subject: 'Mathematics',
    periodLabel: 'Period 1',
    studentCount: 3,
    isPending: true,
  ),
];

List<TeacherAttendanceStudent> _students(List<StudentAttendanceMark> marks) => [
      for (var i = 0; i < marks.length; i++)
        TeacherAttendanceStudent(
          id: 's${i + 1}',
          name: 'Student ${i + 1}',
          rollNo: '0${i + 1}',
          mark: marks[i],
        ),
    ];

// Seed the real read seams (classes + students futures) so bulk mutations write
// the private students state and teacherAttendanceProvider recomputes. A shared
// reliability store lets the test read back what autosave actually persisted.
Widget _app(
  List<StudentAttendanceMark> marks,
  InMemoryReliabilityStore store,
) {
  return ProviderScope(
    overrides: providerTestOverrides([
      reliabilityStoreProvider.overrideWithValue(store),
      teacherAttendanceClassesFutureProvider.overrideWith((ref) async => _classes),
      teacherAttendanceStudentsFutureProvider.overrideWith(
        (ref) async => {_classId: _students(marks)},
      ),
    ]),
    child: MaterialApp(
      theme: AksharaAppTheme.light(),
      home: const TeacherAttendanceScreen(),
    ),
  );
}

ButtonStyleButton _submitButton(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(
      find.byKey(QaTestKeys.teacherAttendanceSubmitButton),
    );

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  testWidgets(
      'F-080 · bulk over already-marked rows prompts confirm; Cancel is a no-op',
      (tester) async {
    final store = InMemoryReliabilityStore();
    // s1 present, s2 absent → 2 rows already marked; s3 still unmarked.
    await tester.pumpWidget(_app(const [
      StudentAttendanceMark.present,
      StudentAttendanceMark.absent,
      StudentAttendanceMark.unmarked,
    ], store));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 present · 1 absent'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'All present'));
    await tester.pumpAndSettle();

    // Confirmation names how many marked rows would be overwritten.
    expect(find.text('Overwrite existing marks?'), findsOneWidget);
    expect(find.textContaining('2 students'), findsOneWidget);

    // Cancel → nothing is applied; the roster is exactly as it was.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Overwrite existing marks?'), findsNothing);
    expect(find.textContaining('1 present · 1 absent'), findsOneWidget);
    expect(find.textContaining('1 unmarked'), findsOneWidget);
  });

  testWidgets('F-080 · a blank roster applies bulk directly (no confirm)',
      (tester) async {
    final store = InMemoryReliabilityStore();
    await tester.pumpWidget(_app(const [
      StudentAttendanceMark.unmarked,
      StudentAttendanceMark.unmarked,
      StudentAttendanceMark.unmarked,
    ], store));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'All present'));
    await tester.pumpAndSettle();

    // No friction when nothing would be overwritten — applied immediately.
    expect(find.text('Overwrite existing marks?'), findsNothing);
    expect(find.textContaining('3 present · 0 absent'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);
    // Undo is still offered.
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets(
      'F-080 · Overwrite → Undo restores the prior roster AND autosave '
      'persists the restored (not wiped) state', (tester) async {
    final store = InMemoryReliabilityStore();
    // Prior roster: s1 present, s2 absent, s3 unmarked.
    await tester.pumpWidget(_app(const [
      StudentAttendanceMark.present,
      StudentAttendanceMark.absent,
      StudentAttendanceMark.unmarked,
    ], store));
    await tester.pumpAndSettle();

    // Destructive bulk → confirm → overwrite everyone to absent.
    await tester.tap(find.widgetWithText(OutlinedButton, 'All absent'));
    await tester.pumpAndSettle();
    expect(find.text('Overwrite existing marks?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Overwrite'));
    await tester.pumpAndSettle();

    // Wiped state: all three absent, submit gate open, Undo offered.
    expect(find.textContaining('0 present · 3 absent'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);

    // Undo → the exact prior roster is back.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 present · 1 absent'), findsOneWidget);
    expect(find.textContaining('1 unmarked'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull,
        reason: 'restoring the unmarked row must re-close the submit gate');

    // Let the debounced autosave (800ms) fire and complete.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    // The persisted draft reflects the RESTORED roster, not the wiped one:
    // s1 stays present (a wiped draft would have marked it absent).
    final record = await store.getDraft(_draftKey);
    expect(record, isNotNull,
        reason: 'autosave must persist the in-progress roster');
    final marks = (record!.json['marks'] as Map).cast<String, dynamic>();
    expect(marks['s1'], StudentAttendanceMark.present.name,
        reason: 'restored roster must be persisted, not the all-absent wipe');
    expect(marks['s2'], StudentAttendanceMark.absent.name);
    // s3 was unmarked in the restored roster → excluded from the saved marks.
    expect(marks.containsKey('s3'), isFalse);
  });
}
