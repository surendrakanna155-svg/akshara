import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/attendance/my_attendance_provider.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_my_attendance_screen.dart';
import 'package:akshara_erp/features/teacher/dashboard/teacher_dashboard_provider.dart';
import 'package:akshara_erp/features/teacher/dashboard/widgets/pending_tasks_section.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_screen.dart';
import 'package:akshara_erp/features/teacher/homework/teacher_homework_screen.dart';
import 'package:akshara_erp/features/teacher/reports/teacher_report_exporters.dart';
import 'package:akshara_erp/features/teacher/timetable/teacher_timetable_screen.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/router/teacher_navigation.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';

Future<void> _pump(WidgetTester tester, Widget screen) async {
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
  group('TCH-9 · My Attendance screen', () {
    testWidgets('renders the summary chips and a day list', (tester) async {
      await _pump(tester, const TeacherMyAttendanceScreen());

      expect(find.byKey(QaTestKeys.teacherMyAttendanceScreen), findsOneWidget);
      expect(find.text('My Attendance'), findsOneWidget);
      // Summary chip subtitles ('Present'/'Late'/'Absent' also appear as day
      // status chips, so assert at least one of each).
      expect(find.text('Present'), findsWidgets);
      expect(find.text('Late'), findsWidgets);
      expect(find.text('Absent'), findsWidgets);
      expect(find.text('Avg hours'), findsOneWidget);
      // At least one day row rendered (mock builds a full month up to today).
      expect(
        find.byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>)
                .value
                .startsWith('teacher_my_attendance_day_')),
        findsWidgets,
      );
      // Today / Yesterday cards.
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('month switcher moves to the previous month', (tester) async {
      late WidgetRef capturedRef;
      useMobileViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides(),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const TeacherMyAttendanceScreen();
              },
            ),
          ),
        ),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(capturedRef.read(myAttendanceMonthProvider), isNull);
      await tester.tap(
        find.byKey(QaTestKeys.teacherMyAttendancePrevMonthButton),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();
      // A concrete YYYY-MM is now selected (no longer the current-month default).
      expect(capturedRef.read(myAttendanceMonthProvider), isNotNull);
    });
  });

  group('TCH-2 · marks-pending dashboard task', () {
    test('mock dashboard surfaces a Marks-to-enter pending task', () {
      final data = TeacherDashboardData.mock();
      expect(
        data.pendingTasks.any((t) => t.id == 'marks_pending'),
        isTrue,
        reason: 'marks_pending task should be derived from marks-entry data',
      );
      final task = data.pendingTasks.firstWhere((t) => t.id == 'marks_pending');
      expect(task.count, greaterThan(0));
      // Demo marks-entry has no past deadline → the task is not overdue.
      expect(task.overdue, isFalse);
      expect(task.label, 'Marks to enter');
    });

    testWidgets('an overdue task is drawn in a different (error) tone',
        (tester) async {
      Color? overdueColor;
      Color? normalColor;
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: PendingTasksSection(
              tasks: [
                PendingTask(
                  id: 'marks_pending',
                  icon: Icons.grading_outlined,
                  count: 12,
                  label: 'Marks overdue',
                  overdue: true,
                ),
                PendingTask(
                  id: 'hw_review',
                  icon: Icons.assignment_outlined,
                  count: 3,
                  label: 'HW to review',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Marks overdue'), findsOneWidget);
      overdueColor =
          tester.widget<Icon>(find.byIcon(Icons.grading_outlined)).color;
      normalColor =
          tester.widget<Icon>(find.byIcon(Icons.assignment_outlined)).color;
      expect(overdueColor, isNotNull);
      expect(overdueColor, isNot(normalColor));
    });
  });

  group('TCH-1 · today-schedule row opens attendance', () {
    testWidgets('schedule_attendance_<label> routes to attendance preselected',
        (tester) async {
      String? capturedClass;
      var hit = false;
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => ElevatedButton(
                  onPressed: () => handleTeacherNavigation(
                    context,
                    'schedule_attendance_8-A',
                  ),
                  child: const Text('go'),
                ),
              ),
              GoRoute(
                path: RouteNames.teacherAttendance,
                builder: (_, state) {
                  hit = true;
                  capturedClass = state.uri.queryParameters['class'];
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(hit, isTrue);
      expect(capturedClass, '8-A');
    });
  });

  group('TCH-3 · marks summary export', () {
    test('marksSummaryRows classifies Complete / Pending / Overdue', () {
      final asOf = DateTime.parse('2026-07-06T12:00:00Z');
      final rows = TeacherReportExporters.marksSummaryRows(
        [
          const MarksEntryProgress(
            examId: 'e1',
            title: 'T',
            subject: 'Maths',
            grade: '8',
            sectionName: 'A',
            enteredCount: 30,
            totalCount: 30,
          ),
          MarksEntryProgress(
            examId: 'e2',
            title: 'T',
            subject: 'Science',
            grade: '9',
            sectionName: 'B',
            enteredCount: 10,
            totalCount: 30,
            marksEntryDeadline: DateTime.parse('2026-07-31T10:00:00Z'),
          ),
          MarksEntryProgress(
            examId: 'e3',
            title: 'T',
            subject: 'English',
            grade: '7',
            sectionName: 'C',
            enteredCount: 5,
            totalCount: 25,
            marksEntryDeadline: DateTime.parse('2026-07-01T10:00:00Z'),
          ),
        ],
        asOf: asOf,
      );
      expect(rows[0].last, 'Complete');
      expect(rows[1].last, 'Pending');
      expect(rows[2], ['7-C', 'English', '5', '25', '20', 'Overdue']);
    });

    testWidgets('teacher exams screen shows a marks-summary export action',
        (tester) async {
      await _pump(tester, const TeacherExamsScreen());
      expect(
        find.byKey(QaTestKeys.teacherMarksSummaryExportButton),
        findsOneWidget,
      );
    });
  });

  group('TCH-5 · create-homework quick action', () {
    test('mock dashboard exposes a create_homework quick action', () {
      final data = TeacherDashboardData.mock();
      expect(
        data.quickActions.any((a) => a.id == 'create_homework'),
        isTrue,
      );
    });

    testWidgets('create_homework nav routes to the create screen',
        (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => ElevatedButton(
                  onPressed: () =>
                      handleTeacherNavigation(context, 'create_homework'),
                  child: const Text('go'),
                ),
              ),
              GoRoute(
                path: RouteNames.teacherHomeworkCreate,
                builder: (_, __) {
                  routes.add(RouteNames.teacherHomeworkCreate);
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(routes, contains(RouteNames.teacherHomeworkCreate));
    });
  });

  group('TCH-9 nav · check-in card opens My Attendance', () {
    testWidgets('staff_check_in routes to my-attendance', (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => ElevatedButton(
                  onPressed: () =>
                      handleTeacherNavigation(context, 'staff_check_in'),
                  child: const Text('go'),
                ),
              ),
              GoRoute(
                path: RouteNames.teacherMyAttendance,
                builder: (_, __) {
                  routes.add(RouteNames.teacherMyAttendance);
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(routes, contains(RouteNames.teacherMyAttendance));
    });
  });

  group('TCH-7 · timetable export button', () {
    testWidgets('renders an export action on the timetable', (tester) async {
      await _pump(tester, const TeacherTimetableScreen());
      expect(
        find.byKey(QaTestKeys.teacherTimetableExportButton),
        findsOneWidget,
      );
    });
  });

  group('TCH-6 · homework review pending-only filter', () {
    testWidgets('the pending deep-link shows only unreviewed submissions',
        (tester) async {
      await _pump(
        tester,
        const TeacherHomeworkScreen(initialPendingOnly: true),
      );
      await tester.pumpAndSettle();

      // The filter chip is shown, and a reviewed submission is hidden.
      expect(find.text('Pending review only'), findsOneWidget);
      // The mock 'hw_8a_1' assignment has a reviewed submission by Karthik Menon
      // (status reviewed) that must be filtered out.
      expect(find.text('Karthik Menon'), findsNothing);
    });
  });
}
