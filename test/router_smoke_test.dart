import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/login_screen.dart';
import 'package:akshara_erp/router/app_router.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

AuthState get _studentAuth => const AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: '9876543210',
      displayName: 'Ravi Kumar',
      role: UserRole.student,
    );

AuthState get _parentAuth => const AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: '9876543210',
      displayName: 'Ravi Kumar',
      role: UserRole.parent,
    );

void main() {
  group('homeRouteForRole', () {
    test('maps each role to its dashboard route', () {
      expect(homeRouteForRole(UserRole.parent), RouteNames.parentDashboard);
      expect(homeRouteForRole(UserRole.teacher), RouteNames.teacherDashboard);
      expect(homeRouteForRole(UserRole.student), RouteNames.studentDashboard);
      expect(homeRouteForRole(UserRole.staff), RouteNames.teacherDashboard);
      expect(homeRouteForRole(null), RouteNames.login);
    });
  });

  group('createAppRouter', () {
    testWidgets('redirects unauthenticated users away from parent routes', (
      tester,
    ) async {
      final router = createAppRouter(
        auth: const AuthState(status: AuthStatus.unauthenticated),
      );

      await pumpAksharaRouter(tester, router: router);
      router.go(RouteNames.parentDashboard);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.login,
      );
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('allows authenticated teacher to reach teacher module routes', (
      tester,
    ) async {
      final router = createAppRouter(
        auth: const AuthState(
          status: AuthStatus.authenticated,
          phoneNumber: '9876543210',
          displayName: 'Priya Sharma',
          role: UserRole.teacher,
        ),
      );

      await pumpAksharaRouter(tester, router: router);

      const routes = <(String, String)>[
        (RouteNames.teacherDashboard, 'Dashboard'),
        (RouteNames.teacherAttendance, 'Mark Attendance'),
        (RouteNames.teacherTimetable, 'Timetable'),
        (RouteNames.teacherHomework, 'Homework Review'),
        (RouteNames.teacherExams, 'Exams'),
        (RouteNames.teacherMessages, 'Messages'),
        (RouteNames.teacherLeave, 'Leave'),
      ];

      for (final (route, title) in routes) {
        router.go(route);
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, route);
        expect(find.text(title), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('allows authenticated parent to reach parent module routes', (
      tester,
    ) async {
      final router = createAppRouter(auth: _parentAuth);
      await pumpAksharaRouter(tester, router: router);

      const routes = <(String, String)>[
        (RouteNames.parentTimetable, 'Timetable'),
        (RouteNames.parentHomework, 'Homework'),
        (RouteNames.parentExams, 'Exams'),
        (RouteNames.parentNotices, 'School Notices'),
        (RouteNames.parentEvents, 'School Events'),
        (RouteNames.parentProfile, 'Profile'),
        (RouteNames.parentPayment, 'Pay Fee'),
        (RouteNames.parentReceipts, 'Receipts'),
        (RouteNames.parentLeave, 'Leave Requests'),
      ];

      for (final (route, title) in routes) {
        router.go(route);
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, route);
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('allows authenticated student to reach student module routes', (
      tester,
    ) async {
      final router = createAppRouter(auth: _studentAuth);
      await pumpAksharaRouter(tester, router: router);

      const routes = <(String, String)>[
        (RouteNames.studentDashboard, 'Home'),
        (RouteNames.studentAttendance, 'Attendance'),
        (RouteNames.studentTimetable, 'Timetable'),
        (RouteNames.studentHomework, 'Homework'),
        (RouteNames.studentExams, 'Exams'),
        (RouteNames.studentNotices, 'Notices'),
        (RouteNames.studentProfile, 'Profile'),
      ];

      for (final (route, title) in routes) {
        router.go(route);
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, route);
        expect(find.text(title), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('blocks student from teacher routes', (tester) async {
      final router = createAppRouter(
        auth: const AuthState(
          status: AuthStatus.authenticated,
          phoneNumber: '9876543210',
          displayName: 'Ravi Kumar',
          role: UserRole.student,
        ),
      );

      await pumpAksharaRouter(tester, router: router);
      router.go(RouteNames.teacherDashboard);
      await tester.pump();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.studentDashboard,
      );
    });
  });
}
