import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_models.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_verification_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/parent/attendance/parent_attendance_screen.dart';
import '../features/parent/dashboard/parent_dashboard_screen.dart';
import '../features/parent/fees/parent_fees_screen.dart';
import '../features/parent/shell/parent_shell.dart';
import '../features/student/dashboard/student_dashboard_screen.dart';
import '../features/student/shell/student_shell.dart';
import '../features/teacher/dashboard/teacher_dashboard_screen.dart';
import '../features/teacher/shell/teacher_shell.dart';
import 'parent_navigation.dart';
import 'route_names.dart';
import 'student_navigation.dart';
import 'teacher_navigation.dart';

/// Creates the application [GoRouter] with auth flow and parent shell routes.
GoRouter createAppRouter({
  Listenable? refreshListenable,
  required AuthState auth,
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: refreshListenable,
    debugLogDiagnostics: true,
    redirect: (context, state) => _authRedirect(auth, state.uri.path),
    routes: [
      GoRoute(
        path: RouteNames.root,
        redirect: (context, state) => RouteNames.splash,
      ),
      GoRoute(
        path: RouteNames.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.otpVerification,
        name: 'otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          final role = UserRole.fromName(state.uri.queryParameters['role']);
          return OtpVerificationScreen(
            phoneNumber: phone,
            role: role,
          );
        },
      ),
      GoRoute(
        path: RouteNames.parent,
        redirect: (context, state) => RouteNames.parentDashboard,
      ),
      GoRoute(
        path: RouteNames.parentNotifications,
        name: 'parentNotifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ParentShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.parentDashboard,
            name: 'parentDashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentDashboardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentAttendance,
            name: 'parentAttendance',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentAttendanceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentFees,
            name: 'parentFees',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentFeesRouteBuilder(context, state),
            ),
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.teacher,
        redirect: (context, state) => RouteNames.teacherDashboard,
      ),
      ShellRoute(
        builder: (context, state, child) => TeacherShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.teacherDashboard,
            name: 'teacherDashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherDashboardRouteBuilder(context, state),
            ),
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.student,
        redirect: (context, state) => RouteNames.studentDashboard,
      ),
      ShellRoute(
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.studentDashboard,
            name: 'studentDashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              child: studentDashboardRouteBuilder(context, state),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Text('No route for: ${state.uri}'),
      ),
    ),
  );
}

String? _authRedirect(AuthState auth, String location) {
  final isSplash = location == RouteNames.splash;
  final isLogin = location == RouteNames.login;
  final isOtp = location == RouteNames.otpVerification;
  final isAuthEntryRoute = isSplash || isLogin || isOtp;

  if (auth.status == AuthStatus.unknown) {
    return isSplash ? null : RouteNames.splash;
  }

  final isAuthenticated = auth.isAuthenticated;
  final isProtectedRoute = _isProtectedRoute(location);

  if (!isAuthenticated && isProtectedRoute) {
    return RouteNames.login;
  }

  if (isAuthenticated && (isLogin || isOtp)) {
    return homeRouteForRole(auth.role);
  }

  if (isSplash) {
    return null;
  }

  if (!isAuthenticated && !isAuthEntryRoute && location == RouteNames.root) {
    return RouteNames.splash;
  }

  if (isAuthenticated && isProtectedRoute && !_canAccessRoute(auth, location)) {
    return homeRouteForRole(auth.role);
  }

  return null;
}

bool _isProtectedRoute(String location) {
  return location.startsWith('/parent') ||
      location.startsWith('/teacher') ||
      location.startsWith('/student');
}

bool _canAccessRoute(AuthState auth, String location) {
  return switch (auth.role) {
    UserRole.parent => location.startsWith('/parent'),
    UserRole.teacher => location.startsWith('/teacher'),
    UserRole.student => location.startsWith('/student'),
    UserRole.staff => location.startsWith('/teacher'),
    null => false,
  };
}

/// Role-based home route after login, OTP, or splash bootstrap.
String homeRouteForRole(UserRole? role) {
  return switch (role) {
    UserRole.parent => RouteNames.parentDashboard,
    UserRole.teacher => RouteNames.teacherDashboard,
    UserRole.student => RouteNames.studentDashboard,
    UserRole.staff => RouteNames.teacherDashboard,
    null => RouteNames.login,
  };
}

/// Dashboard screen wired with router navigation.
Widget parentDashboardRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentDashboardScreen(
    onNavigate: (actionId) => handleParentDashboardNavigation(context, actionId),
  );
}

/// Attendance screen with notification bell routing.
Widget parentAttendanceRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentAttendanceScreen(
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
  );
}

/// Fees screen with notification bell routing.
Widget parentFeesRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentFeesScreen(
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
  );
}

/// Teacher dashboard wired with router navigation.
Widget teacherDashboardRouteBuilder(BuildContext context, GoRouterState state) {
  return TeacherDashboardScreen(
    onNavigate: (actionId) => handleTeacherNavigation(context, actionId),
  );
}

/// Student dashboard wired with router navigation.
Widget studentDashboardRouteBuilder(BuildContext context, GoRouterState state) {
  return StudentDashboardScreen(
    onNavigate: (actionId) => handleStudentNavigation(context, actionId),
  );
}
