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
              path: RouteNames.teacherClassTeacherDashboard,
              builder: (_, __) {
                onRoute(RouteNames.teacherClassTeacherDashboard);
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
              path: RouteNames.teacherHomeworkCreate,
              builder: (_, __) {
                onRoute(RouteNames.teacherHomeworkCreate);
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
            GoRoute(
              path: RouteNames.teacherProfile,
              builder: (_, __) {
                onRoute(RouteNames.teacherProfile);
                return const SizedBox();
              },
            ),
            GoRoute(
              path: RouteNames.teacherNotifications,
              builder: (_, __) {
                onRoute(RouteNames.teacherNotifications);
                return const SizedBox();
              },
            ),
            GoRoute(
              path: '${RouteNames.teacher}/student-risk/:sisStudentId',
              builder: (_, state) {
                onRoute(
                  RouteNames.teacherStudentRisk(
                    state.pathParameters['sisStudentId'] ?? '',
                  ),
                );
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

  testWidgets('teacher create_homework routes to create screen', (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleTeacherNavigation(context, 'create_homework'),
      routes.add,
    );
    expect(routes, contains(RouteNames.teacherHomeworkCreate));
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

  testWidgets(
    'teacher class_teacher_dashboard routes to class teacher dashboard',
    (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) =>
          handleTeacherNavigation(context, 'class_teacher_dashboard'),
      routes.add,
    );
    expect(routes, contains(RouteNames.teacherClassTeacherDashboard));
  });

  // F-163 — the dashboard "Students requiring attention → Review" tap emits a
  // `student_risk_<id>` action id and must land on that student's risk detail.
  testWidgets('teacher student_risk_<id> routes to student risk detail',
      (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleTeacherNavigation(context, 'student_risk_stu-42'),
      routes.add,
    );
    expect(routes, contains(RouteNames.teacherStudentRisk('stu-42')));
  });

  // F-164 — the profile avatar opens the teacher profile, not Home.
  testWidgets('teacher profile routes to teacher profile', (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleTeacherNavigation(context, 'profile'),
      routes.add,
    );
    expect(routes, contains(RouteNames.teacherProfile));
    expect(routes, isNot(contains(RouteNames.teacherDashboard)));
  });

  // F-128 — the teacher bell opens the teacher-scoped notifications inbox, not
  // the parent persona's route.
  testWidgets('teacher notifications routes to teacher notifications',
      (tester) async {
    final routes = <String>[];
    await pumpNavHarness(
      tester,
      (context) => handleTeacherNavigation(context, 'notifications'),
      routes.add,
    );
    expect(routes, contains(RouteNames.teacherNotifications));
  });
}
