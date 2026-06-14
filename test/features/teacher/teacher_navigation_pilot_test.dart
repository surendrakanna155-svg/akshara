import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/router/teacher_navigation.dart';
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
              path: RouteNames.teacherDashboard,
              builder: (_, __) {
                onRoute(RouteNames.teacherDashboard);
                return const SizedBox();
              },
            ),
            GoRoute(
              path: RouteNames.teacherAttendance,
              builder: (_, __) {
                onRoute(RouteNames.teacherAttendance);
                return const SizedBox();
              },
            ),
            GoRoute(
              path: RouteNames.teacherHomework,
              builder: (_, __) {
                onRoute(RouteNames.teacherHomework);
                return const SizedBox();
              },
            ),
            GoRoute(
              path: RouteNames.teacherTimetable,
              builder: (_, __) {
                onRoute(RouteNames.teacherTimetable);
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

  testWidgets('teacher mark_attendance routes to attendance', (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleTeacherNavigation(context, 'mark_attendance'),
      routes.add,
    );
    expect(routes, contains(RouteNames.teacherAttendance));
  });

  testWidgets('teacher homework routes to homework screen', (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleTeacherNavigation(context, 'homework'),
      routes.add,
    );
    expect(routes, contains(RouteNames.teacherHomework));
  });

  testWidgets('teacher ai_copilot routes to assistant', (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleTeacherNavigation(context, 'ai_copilot'),
      routes.add,
    );
    expect(routes, contains(RouteNames.aiAssistant));
  });

  testWidgets('teacher class_teacher_dashboard routes to attendance', (
    tester,
  ) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) =>
          handleTeacherNavigation(context, 'class_teacher_dashboard'),
      routes.add,
    );
    expect(routes, contains(RouteNames.teacherAttendance));
  });
}
