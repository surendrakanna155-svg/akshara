import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_provider.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

/// ATT-3 — absentees-first fast-mark: "Fill remaining present" marks only the
/// still-unmarked students present, leaving explicit absent/late marks intact,
/// so the submit gate then opens.

const _classes = [
  TeacherAttendanceClass(
    id: 'class-8a-p1',
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

// Seed the real read seams (classes + students futures) so the marking
// mutations (which write the private students state) actually take effect and
// teacherAttendanceProvider recomputes — unlike a static value override.
Widget _app(List<StudentAttendanceMark> marks) {
  return ProviderScope(
    overrides: providerTestOverrides([
      teacherAttendanceClassesFutureProvider.overrideWith((ref) async => _classes),
      teacherAttendanceStudentsFutureProvider.overrideWith(
        (ref) async => {'class-8a-p1': _students(marks)},
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

  testWidgets('ATT-3 · Fill remaining present opens the submit gate',
      (tester) async {
    // One absentee already marked; the other two are unmarked → submit blocked.
    await tester.pumpWidget(_app(const [
      StudentAttendanceMark.absent,
      StudentAttendanceMark.unmarked,
      StudentAttendanceMark.unmarked,
    ]));
    await tester.pumpAndSettle();
    expect(_submitButton(tester).onPressed, isNull);
    expect(find.textContaining('2 unmarked'), findsOneWidget);

    // Tap "Fill remaining present" → the two unmarked become present, the
    // explicit absent is preserved, and the gate opens.
    await tester.ensureVisible(
      find.byKey(QaTestKeys.teacherAttendanceFillRemainingButton),
    );
    await tester.tap(
      find.byKey(QaTestKeys.teacherAttendanceFillRemainingButton),
    );
    await tester.pumpAndSettle();

    expect(_submitButton(tester).onPressed, isNotNull,
        reason: 'filling remaining as present must mark every student');
    expect(find.textContaining('unmarked'), findsNothing);
  });
}
