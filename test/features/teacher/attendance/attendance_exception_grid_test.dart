import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/attendance/widgets/attendance_exception_grid.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P2-UX-2 §2.1 — the exception grid: a tap cycles the mark, a long-press opens
/// the full picker. Marking is delegated to the caller (the real workflow), so
/// this covers only the interaction contract.
void main() {
  const students = [
    TeacherAttendanceStudent(
      id: 's1',
      name: 'Arjun Das',
      rollNo: '05',
      mark: StudentAttendanceMark.present,
    ),
    TeacherAttendanceStudent(
      id: 's2',
      name: 'Ananya Rao',
      rollNo: '02',
      mark: StudentAttendanceMark.absent,
    ),
  ];

  Future<Map<String, StudentAttendanceMark>> pumpGrid(WidgetTester tester) async {
    final marks = <String, StudentAttendanceMark>{};
    await tester.pumpWidget(
      MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: AttendanceExceptionGrid(
            students: students,
            enabled: true,
            onMark: (id, mark) => marks[id] = mark,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return marks;
  }

  testWidgets('renders one tile per student with the full name', (tester) async {
    await pumpGrid(tester);
    expect(find.text('Arjun Das'), findsOneWidget);
    expect(find.text('Ananya Rao'), findsOneWidget);
    expect(
      find.byKey(QaTestKeys.teacherAttendanceExceptionTile('s1')),
      findsOneWidget,
    );
  });

  testWidgets('tapping a present tile cycles it to absent', (tester) async {
    final marks = await pumpGrid(tester);
    await tester.tap(find.byKey(QaTestKeys.teacherAttendanceExceptionTile('s1')));
    await tester.pump();
    // present → absent (the fast exception cycle).
    expect(marks['s1'], StudentAttendanceMark.absent);
  });

  testWidgets('long-press opens the picker for the rarer marks',
      (tester) async {
    final marks = await pumpGrid(tester);
    await tester
        .longPress(find.byKey(QaTestKeys.teacherAttendanceExceptionTile('s1')));
    await tester.pumpAndSettle();

    // The full picker offers half-day / excused (unreachable via the tap cycle).
    await tester.tap(
      find.byKey(QaTestKeys.teacherAttendancePickMark('s1', 'halfDay')),
    );
    await tester.pumpAndSettle();
    expect(marks['s1'], StudentAttendanceMark.halfDay);
  });

  testWidgets('a disabled grid ignores taps', (tester) async {
    final marks = <String, StudentAttendanceMark>{};
    await tester.pumpWidget(
      MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: AttendanceExceptionGrid(
            students: students,
            enabled: false,
            onMark: (id, mark) => marks[id] = mark,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QaTestKeys.teacherAttendanceExceptionTile('s1')));
    await tester.pump();
    expect(marks, isEmpty);
  });

  test('cycle order is present → absent → late → present', () {
    expect(
      AttendanceExceptionGrid.cycle(StudentAttendanceMark.present),
      StudentAttendanceMark.absent,
    );
    expect(
      AttendanceExceptionGrid.cycle(StudentAttendanceMark.absent),
      StudentAttendanceMark.late,
    );
    expect(
      AttendanceExceptionGrid.cycle(StudentAttendanceMark.late),
      StudentAttendanceMark.present,
    );
    expect(
      AttendanceExceptionGrid.cycle(StudentAttendanceMark.unmarked),
      StudentAttendanceMark.present,
    );
  });
}
