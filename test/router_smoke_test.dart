import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/login_screen.dart';
import 'package:akshara_erp/router/app_router.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

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

    testWidgets('allows authenticated teacher to reach teacher dashboard', (
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
      router.go(RouteNames.teacherDashboard);
      await tester.pump();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.teacherDashboard,
      );
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
