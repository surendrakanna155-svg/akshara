import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_provider.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_screen.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_screen.dart';
import 'package:akshara_erp/features/teacher/homework/teacher_homework_provider.dart';
import 'package:akshara_erp/features/teacher/homework/teacher_homework_screen.dart';
import 'package:akshara_erp/features/teacher/leave/teacher_leave_provider.dart';
import 'package:akshara_erp/features/teacher/leave/teacher_leave_screen.dart';
import 'package:akshara_erp/features/teacher/messages/teacher_conversation_screen.dart';
import 'package:akshara_erp/features/teacher/messages/teacher_messages_screen.dart';
import 'package:akshara_erp/features/teacher/timetable/teacher_timetable_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

Future<void> pumpTeacherScreen(WidgetTester tester, Widget screen) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Teacher module screens', () {
    testWidgets('TeacherAttendanceScreen renders roster and actions', (
      tester,
    ) async {
      await pumpTeacherScreen(tester, const TeacherAttendanceScreen());

      expect(find.text('Mark Attendance'), findsOneWidget);
      expect(find.text('All present'), findsOneWidget);
      expect(find.text('Save draft'), findsOneWidget);
      expect(find.textContaining('unmarked'), findsOneWidget);
    });

    testWidgets('TeacherAttendanceScreen shows loading state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherAttendanceLoadingProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const TeacherAttendanceScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('TeacherTimetableScreen renders weekly schedule', (
      tester,
    ) async {
      await pumpTeacherScreen(tester, const TeacherTimetableScreen());

      expect(find.text('Timetable'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.textContaining('Mathematics'), findsWidgets);
    });

    testWidgets('TeacherHomeworkScreen renders review queue', (tester) async {
      await pumpTeacherScreen(tester, const TeacherHomeworkScreen());

      expect(find.text('Homework Review'), findsOneWidget);
      expect(find.textContaining('Pending review'), findsWidgets);
    });

    testWidgets('TeacherHomeworkScreen shows empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherHomeworkEmptyProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const TeacherHomeworkScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });

    testWidgets('TeacherExamsScreen renders exam sections', (tester) async {
      await pumpTeacherScreen(tester, const TeacherExamsScreen());

      expect(find.text('Exams'), findsOneWidget);
      expect(find.text('Upcoming'), findsWidgets);
      expect(find.text('Marks entry'), findsOneWidget);
    });

    testWidgets('TeacherMessagesScreen renders inbox', (tester) async {
      await pumpTeacherScreen(tester, const TeacherMessagesScreen());

      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Suresh Kumar'), findsOneWidget);
    });

    testWidgets('TeacherConversationScreen renders thread', (tester) async {
      await pumpTeacherScreen(
        tester,
        const TeacherConversationScreen(threadId: 'thread_1'),
      );

      expect(find.text('Suresh Kumar'), findsOneWidget);
      expect(
        find.textContaining('homework solution steps'),
        findsOneWidget,
      );
    });

    testWidgets('TeacherLeaveScreen renders balance and history', (
      tester,
    ) async {
      await pumpTeacherScreen(tester, const TeacherLeaveScreen());

      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Casual'), findsOneWidget);
      expect(find.text('Apply leave'), findsOneWidget);
    });

    testWidgets('TeacherLeaveScreen shows error state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherLeaveErrorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const TeacherLeaveScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
