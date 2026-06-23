import 'package:akshara_erp/features/student_app/attendance/student_attendance_provider.dart';
import 'package:akshara_erp/features/student_app/attendance/student_attendance_screen.dart';
import 'package:akshara_erp/features/student_app/exams/student_exams_screen.dart';
import 'package:akshara_erp/features/student_app/homework/student_homework_provider.dart';
import 'package:akshara_erp/features/student_app/homework/student_homework_screen.dart';
import 'package:akshara_erp/features/student_app/notices/student_notices_provider.dart';
import 'package:akshara_erp/features/student_app/notices/student_notices_screen.dart';
import 'package:akshara_erp/features/student_app/profile/student_profile_provider.dart';
import 'package:akshara_erp/features/student_app/profile/student_profile_screen.dart';
import 'package:akshara_erp/features/student_app/timetable/student_timetable_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

Future<void> pumpStudentScreen(WidgetTester tester, Widget screen) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('Student module screens', () {
    testWidgets('StudentAttendanceScreen renders calendar and history', (
      tester,
    ) async {
      await pumpStudentScreen(tester, const StudentAttendanceScreen());

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Attendance history'), findsOneWidget);
      expect(find.textContaining('attendance'), findsWidgets);
    });

    testWidgets('StudentAttendanceScreen shows loading state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            studentAttendanceLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const StudentAttendanceScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('StudentTimetableScreen renders weekly schedule', (
      tester,
    ) async {
      await pumpStudentScreen(tester, const StudentTimetableScreen());

      expect(find.text('Timetable'), findsOneWidget);
      expect(find.textContaining('Mathematics'), findsWidgets);
    });

    testWidgets('StudentHomeworkScreen renders homework filters', (
      tester,
    ) async {
      await pumpStudentScreen(tester, const StudentHomeworkScreen());

      expect(find.text('Homework'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
    });

    testWidgets('StudentHomeworkScreen shows empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            studentHomeworkEmptyProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const StudentHomeworkScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });

    testWidgets('StudentExamsScreen renders exam sections', (tester) async {
      await pumpStudentScreen(tester, const StudentExamsScreen());

      expect(find.text('Exams'), findsOneWidget);
      expect(find.text('Upcoming'), findsWidgets);
      expect(find.text('Subject-wise scores'), findsNothing);
    });

    testWidgets('StudentNoticesScreen renders notice filters', (tester) async {
      await pumpStudentScreen(tester, const StudentNoticesScreen());

      expect(find.text('Notices'), findsOneWidget);
      expect(find.text('School'), findsWidgets);
    });

    testWidgets('StudentNoticesScreen shows error state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            studentNoticesErrorProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const StudentNoticesScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });

    testWidgets('StudentProfileScreen renders student and parent details', (
      tester,
    ) async {
      await pumpStudentScreen(tester, const StudentProfileScreen());

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsWidgets);
      expect(find.text('Parent details'), findsOneWidget);
      expect(find.text('App settings'), findsOneWidget);
    });

    testWidgets('StudentProfileScreen shows error state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            studentProfileErrorProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const StudentProfileScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
