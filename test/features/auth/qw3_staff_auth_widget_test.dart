import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/splash_screen.dart';
import 'package:akshara_erp/features/auth/staff/staff_login_provider.dart';
import 'package:akshara_erp/features/auth/staff/staff_login_screen.dart';
import 'package:akshara_erp/features/auth/staff/staff_otp_screen.dart';
import 'package:akshara_erp/router/app_router.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-003 (staff login + staff OTP screens) and
/// QA-F-004 (splash → role-aware routing render).
///
/// `staff_login_screen.dart`, `staff_otp_screen.dart` and the router-driven
/// splash redirect were never pumped in a widget test. These cover render,
/// field validation gating, the OTP verify path + error state, and the splash
/// loading visual + unauthenticated redirect target.

/// Pumps a single screen inside a tiny GoRouter so `context.go` calls in the
/// staff auth screens resolve to a real navigator (no crash, no real nav).
Future<void> _pumpHosted(WidgetTester tester, Widget screen) async {
  useMobileViewport(tester);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => screen),
      GoRoute(
        path: RouteNames.staffOtp,
        builder: (_, __) => const Scaffold(body: Text('staff-otp-route')),
      ),
      GoRoute(
        path: RouteNames.staffLogin,
        builder: (_, __) => const Scaffold(body: Text('staff-login-route')),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (_, __) => const Scaffold(body: Text('login-route')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp.router(
        theme: AksharaAppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('QA-F-003 · StaffLoginScreen', () {
    testWidgets('renders the identifier field, segments and send button',
        (tester) async {
      await _pumpHosted(tester, const StaffLoginScreen());

      expect(find.text('Staff sign in'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Send OTP'), findsOneWidget);
    });

    testWidgets('rejects an invalid email on submit', (tester) async {
      await _pumpHosted(tester, const StaffLoginScreen());

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.widgetWithText(FilledButton, 'Send OTP'));
      await tester.pump();

      // Validation fails → inline error shown, still on the login form.
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Staff sign in'), findsOneWidget);
    });

    testWidgets('accepts a valid email then advances to the OTP route',
        (tester) async {
      await _pumpHosted(tester, const StaffLoginScreen());

      await tester.enterText(find.byType(TextFormField), 'admin@school.edu');
      await tester.tap(find.widgetWithText(FilledButton, 'Send OTP'));
      // sendOtp has a 500ms mock delay; pump past it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Mock workflow succeeds → navigates to the staff OTP route.
      expect(find.text('staff-otp-route'), findsOneWidget);
    });
  });

  group('QA-F-003 · StaffOtpScreen', () {
    testWidgets('renders the OTP field, identifier and verify button',
        (tester) async {
      await _pumpHosted(
        tester,
        const StaffOtpScreen(
          identifier: 'admin@school.edu',
          identifierType: StaffLoginIdentifierType.email,
        ),
      );

      expect(find.text('Enter the OTP sent to'), findsOneWidget);
      expect(find.text('admin@school.edu'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Verify & sign in'),
        findsOneWidget,
      );
      // Countdown gates the resend button at 30s.
      expect(find.textContaining('Resend OTP in'), findsOneWidget);

      // Tear down so the periodic resend Timer is cancelled.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows an error state for a wrong OTP', (tester) async {
      await _pumpHosted(
        tester,
        const StaffOtpScreen(
          identifier: 'admin@school.edu',
          identifierType: StaffLoginIdentifierType.email,
        ),
      );

      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.tap(find.widgetWithText(FilledButton, 'Verify & sign in'));
      // verifyOtp has a 500ms mock delay; pump past it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      // Wrong OTP → error surface rendered, still on the verify screen.
      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(find.textContaining('Invalid OTP'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('QA-F-004 · SplashScreen', () {
    testWidgets('renders the branded loading visual before redirect',
        (tester) async {
      useMobileViewport(tester);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
          GoRoute(
            path: RouteNames.login,
            builder: (_, __) => const Scaffold(body: Text('login-route')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides(),
          child: MaterialApp.router(
            theme: AksharaAppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      // Single frame — before the 2s splash delay completes.
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Drain the 2s bootstrap delay + redirect so no Timer leaks past the test.
      await tester.pump(kStartupSettleDuration);
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('redirects an unauthenticated session to the auth entry',
        (tester) async {
      final router = createAppRouter(
        readAuth: () => const AuthState(status: AuthStatus.unauthenticated),
      );

      // pumpAksharaRouter pumps the splash duration so the redirect resolves.
      await pumpAksharaRouter(tester, router: router);
      await tester.pumpAndSettle();

      // Unauthenticated bootstrap routes to the login / qa-login entry — never
      // stays on splash.
      final landed = router.routeInformationProvider.value.uri.path;
      expect(
        landed == RouteNames.login || landed == RouteNames.qaLogin,
        isTrue,
        reason: 'expected auth entry route, got $landed',
      );
      expect(find.byType(SplashScreen), findsNothing);
    });
  });
}
