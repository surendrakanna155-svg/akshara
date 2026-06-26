import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/router/student_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpNavHarness(
    WidgetTester tester,
    void Function(BuildContext context) navigate,
    void Function(String route) onRoute,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => ElevatedButton(
                onPressed: () => navigate(context),
                child: const Text('navigate'),
              ),
            ),
            GoRoute(
              path: RouteNames.studentDashboard,
              builder: (_, __) {
                onRoute(RouteNames.studentDashboard);
                return const SizedBox();
              },
            ),
            GoRoute(
              path: RouteNames.studentHomework,
              builder: (_, __) {
                onRoute(RouteNames.studentHomework);
                return const SizedBox();
              },
            ),
            GoRoute(
              path: RouteNames.studentTimetable,
              builder: (_, __) {
                onRoute(RouteNames.studentTimetable);
                return const SizedBox();
              },
            ),
            GoRoute(
              path: RouteNames.studentExams,
              builder: (_, __) {
                onRoute(RouteNames.studentExams);
                return const SizedBox();
              },
            ),
            GoRoute(
              path: RouteNames.studentReportCard,
              builder: (_, __) {
                onRoute(RouteNames.studentReportCard);
                return const SizedBox();
              },
            ),
            GoRoute(
              path: RouteNames.studentProgress,
              builder: (_, __) {
                onRoute(RouteNames.studentProgress);
                return const SizedBox();
              },
            ),
            GoRoute(
              path: RouteNames.aiAssistant,
              builder: (_, __) {
                onRoute(RouteNames.aiAssistant);
                return const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('navigate'));
    await tester.pumpAndSettle();
  }

  testWidgets('student homework_list routes to homework', (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleStudentNavigation(context, 'homework_list'),
      routes.add,
    );
    expect(routes, contains(RouteNames.studentHomework));
  });

  testWidgets('student join_class is removed (no navigation)', (tester) async {
    // STU-7: there is no live-class feature; the action no longer exists and
    // must not navigate anywhere (was misleadingly routing to the timetable).
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleStudentNavigation(context, 'join_class'),
      routes.add,
    );
    expect(routes, isEmpty);
  });

  testWidgets('student ai_assistant routes to persona shell', (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleStudentNavigation(context, 'ai_assistant'),
      routes.add,
    );
    expect(routes, contains(RouteNames.aiAssistant));
  });

  testWidgets('student exam prefix routes to exams', (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleStudentNavigation(context, 'exam_midterm_1'),
      routes.add,
    );
    expect(routes, contains(RouteNames.studentExams));
  });

  testWidgets('student report_card routes to report card screen', (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleStudentNavigation(context, 'report_card'),
      routes.add,
    );
    expect(routes, contains(RouteNames.studentReportCard));
  });

  testWidgets('student progress routes to progress screen', (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleStudentNavigation(context, 'progress'),
      routes.add,
    );
    expect(routes, contains(RouteNames.studentProgress));
  });
}
