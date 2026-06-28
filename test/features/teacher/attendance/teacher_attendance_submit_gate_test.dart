import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_provider.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

/// QW1 · QA-F-036 — Teacher attendance "must mark all before submit" gate.
/// Pumps [TeacherAttendanceScreen] and asserts the Submit button is disabled
/// while any student is unmarked, enables once every student is marked, and is
/// re-disabled after the roster is submitted. Complements
/// teacher_attendance_search_test.dart (roster filtering).

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

TeacherAttendanceData _roster(
  List<StudentAttendanceMark> marks, {
  bool isSubmitted = false,
}) {
  return TeacherAttendanceData(
    classes: _classes,
    students: [
      for (var i = 0; i < marks.length; i++)
        TeacherAttendanceStudent(
          id: 's${i + 1}',
          name: 'Student ${i + 1}',
          rollNo: '0${i + 1}',
          mark: marks[i],
        ),
    ],
    selectedClassId: 'class-8a-p1',
    unreadNotifications: 0,
    isSubmitted: isSubmitted,
  );
}

Widget _app(TeacherAttendanceData data) {
  return ProviderScope(
    overrides: providerTestOverrides([
      teacherAttendanceProvider.overrideWithValue(data),
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

  group('QA-F-036 · Teacher attendance submit gate', () {
    testWidgets('Submit is DISABLED while a student is unmarked', (tester) async {
      await tester.pumpWidget(_app(_roster(const [
        StudentAttendanceMark.unmarked,
        StudentAttendanceMark.present,
        StudentAttendanceMark.late,
      ])));
      await tester.pumpAndSettle();

      expect(_submitButton(tester).onPressed, isNull,
          reason: 'one unmarked student must block submit');
      // The action bar surfaces the outstanding count.
      expect(find.textContaining('1 unmarked'), findsOneWidget);
    });

    testWidgets('Submit ENABLES once every student is marked', (tester) async {
      await tester.pumpWidget(_app(_roster(const [
        StudentAttendanceMark.present,
        StudentAttendanceMark.absent,
        StudentAttendanceMark.late,
      ])));
      await tester.pumpAndSettle();

      expect(_submitButton(tester).onPressed, isNotNull,
          reason: 'a fully-marked roster must allow submit');
    });

    testWidgets('Submit is re-DISABLED after the roster is submitted',
        (tester) async {
      await tester.pumpWidget(_app(_roster(
        const [
          StudentAttendanceMark.present,
          StudentAttendanceMark.absent,
          StudentAttendanceMark.late,
        ],
        isSubmitted: true,
      )));
      await tester.pumpAndSettle();

      expect(_submitButton(tester).onPressed, isNull,
          reason: 'an already-submitted roster must not resubmit');
    });
  });
}
