import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_provider.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  const roster = TeacherAttendanceData(
    classes: [
      TeacherAttendanceClass(
        id: 'class-8a-p1',
        label: 'Class 8-A',
        subject: 'Mathematics',
        periodLabel: 'Period 1',
        studentCount: 3,
        isPending: true,
      ),
    ],
    students: [
      TeacherAttendanceStudent(
        id: 's1',
        name: 'Arjun Das',
        rollNo: '05',
        mark: StudentAttendanceMark.unmarked,
      ),
      TeacherAttendanceStudent(
        id: 's2',
        name: 'Ananya Rao',
        rollNo: '02',
        mark: StudentAttendanceMark.present,
      ),
      TeacherAttendanceStudent(
        id: 's3',
        name: 'Karthik Menon',
        rollNo: '03',
        mark: StudentAttendanceMark.late,
      ),
    ],
    selectedClassId: 'class-8a-p1',
    unreadNotifications: 0,
  );

  Widget buildTestApp() {
    return ProviderScope(
      overrides: providerTestOverrides([
        teacherAttendanceProvider.overrideWithValue(roster),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const TeacherAttendanceScreen(),
      ),
    );
  }

  group('TeacherAttendanceScreen search', () {
    testWidgets('shows the full roster before searching', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Arjun Das'), findsOneWidget);
      expect(find.text('Ananya Rao'), findsOneWidget);
      expect(find.text('Karthik Menon'), findsOneWidget);
    });

    testWidgets('filters the roster by name', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(QaTestKeys.teacherAttendanceSearchField),
        'Karthik',
      );
      await tester.pumpAndSettle();

      expect(find.text('Karthik Menon'), findsOneWidget);
      expect(find.text('Arjun Das'), findsNothing);
      expect(find.text('Ananya Rao'), findsNothing);
    });

    testWidgets('filters by roll number too', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(QaTestKeys.teacherAttendanceSearchField),
        '02',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ananya Rao'), findsOneWidget);
      expect(find.text('Arjun Das'), findsNothing);
    });

    testWidgets('shows empty state when nothing matches', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(QaTestKeys.teacherAttendanceSearchField),
        'Zzz No Match',
      );
      await tester.pumpAndSettle();

      expect(find.text('No students match your search.'), findsOneWidget);
    });
  });
}
