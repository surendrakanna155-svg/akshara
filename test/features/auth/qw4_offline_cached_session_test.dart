import 'package:akshara_erp/core/auth/auth_providers.dart';
import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/auth/splash_screen.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/provider_test_overrides.dart';
import '../../test_helpers.dart';

/// QW4 · QA-X-003 — graceful degradation when the login/server is unreachable.
///
/// Cold-starts the real [SplashScreen] → [AuthNotifier.resolveSession] against
/// device storage with NO reachable backend (demo/offline environment performs
/// zero network I/O on the restore path), then asserts the app:
///   • does not crash,
///   • does not get stuck on the splash spinner forever (no infinite spinner),
///   • restores a previously-cached session and routes to an authenticated home
///     — a returning user who opens the app offline still gets in; and, with no
///     cache, degrades cleanly to the auth entry instead of hanging.
///
/// The router is wired to the LIVE [authProvider] (exactly as the production
/// `goRouterProvider` is) so the splash's post-bootstrap `context.go` is honored
/// once `resolveSession()` flips the cached session to authenticated.

/// Seeds a real persisted staff session into [prefs] using the production
/// [AuthNotifier] (writes session + demo tokens to storage, no network), then
/// disposes the container — leaving only the on-device cache behind, exactly as
/// a prior app run would.
Future<void> _seedCachedStaffSession(SharedPreferences prefs) async {
  await initProviderTestPrefs();
  final container = ProviderContainer(
    overrides: providerTestOverrides([
      sharedPreferencesProvider.overrideWithValue(prefs),
      environmentProvider.overrideWith(
        (ref) => Environment.development.copyWith(enableQaLogin: true),
      ),
    ]),
  );
  addTearDown(container.dispose);

  await container.read(authProvider.notifier).signInStaff(
        phoneNumber: '9999999999',
        displayName: 'Returning Admin',
        erpRole: ErpRole.superAdmin,
      );
  expect(container.read(authProvider).isAuthenticated, isTrue);
  // signInStaff schedules a token-refresh Timer in THIS container's session
  // manager; cancel it before disposing so it doesn't leak into the test.
  container.read(authSessionManagerProvider).clearScheduledRefresh();
}

/// A [Listenable] driven by a Riverpod listener so the GoRouter re-runs its
/// redirect when [authProvider] changes (mirrors `routerRefreshNotifierProvider`
/// in production).
class _AuthRefresh extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// A minimal router that hosts the REAL [SplashScreen] and reproduces the
/// production auth-gate redirect (unknown → stay on splash; unauthenticated →
/// auth entry; authenticated → allowed through), but routes the authenticated
/// landing to a lightweight stub instead of the heavy super-admin dashboard.
///
/// This keeps the genuine QA-X-003 logic under test — `SplashScreen` +
/// `resolveSession()` restoring a cached session offline and the resulting
/// route decision — without pulling in dashboard-level timers/animations that
/// would otherwise outlive the test.
GoRouter _minimalRouter({
  required AuthState Function() readAuth,
  required bool Function() readQaLoginEnabled,
  required Listenable refresh,
}) {
  String authEntry() =>
      readQaLoginEnabled() ? RouteNames.qaLogin : RouteNames.login;

  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = readAuth();
      final location = state.uri.path;
      final onSplash = location == RouteNames.splash;
      if (auth.status == AuthStatus.unknown) {
        return onSplash ? null : RouteNames.splash;
      }
      if (!auth.isAuthenticated) {
        return (location == RouteNames.login || location == RouteNames.qaLogin)
            ? null
            : authEntry();
      }
      // Authenticated: send a splash-stuck user into the (stub) home.
      return onSplash ? RouteNames.admin : null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.admin,
        builder: (_, __) => const Scaffold(body: Text('admin-home-stub')),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (_, __) => const Scaffold(body: Text('login-stub')),
      ),
      GoRoute(
        path: RouteNames.qaLogin,
        builder: (_, __) => const Scaffold(body: Text('qa-login-stub')),
      ),
    ],
  );
}

/// Pumps the real splash hosted in [_minimalRouter], wired to the live
/// [authProvider]. Returns the router so the test can read where it landed.
Future<GoRouter> _pumpApp(WidgetTester tester, SharedPreferences prefs) async {
  await initProviderTestPrefs();
  useMobileViewport(tester);

  late GoRouter router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: providerTestOverrides([
        sharedPreferencesProvider.overrideWithValue(prefs),
        environmentProvider.overrideWith(
          (ref) => Environment.development.copyWith(enableQaLogin: true),
        ),
      ]),
      child: Consumer(
        builder: (context, ref, _) {
          final refresh = _AuthRefresh();
          ref.listen<AuthState>(authProvider, (_, __) => refresh.bump());
          router = _minimalRouter(
            readAuth: () => ref.read(authProvider),
            readQaLoginEnabled: () => ref.read(isQaLoginEnabledProvider),
            refresh: refresh,
          );
          return MaterialApp.router(
            theme: AksharaAppTheme.light(),
            routerConfig: router,
          );
        },
      ),
    ),
  );
  return router;
}

/// Drives the splash bootstrap to completion. The bootstrap interleaves a
/// fake-clock 2s timer (the splash delay) with genuinely-async device-storage
/// reads (`resolveSession`), so neither pumps alone nor `runAsync` alone is
/// enough — this alternates real-async draining with fake-clock advancement
/// until the splash redirect has fired (or a generous bound is hit).
Future<void> _drainBootstrap(WidgetTester tester) async {
  await tester.pump(SplashScreen.splashDuration);
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(SplashScreen).evaluate().isEmpty) return;
  }
}

/// Cancels the (1h) token-refresh Timer that restoring an authenticated session
/// schedules, so the test doesn't trip the "Timer still pending" invariant.
void _cancelScheduledRefresh(WidgetTester tester) {
  final element = tester.element(find.byType(MaterialApp));
  final container = ProviderScope.containerOf(element);
  container.read(authSessionManagerProvider).clearScheduledRefresh();
}

void main() {
  testWidgets(
      'QA-X-003 cold start with a cached session + no network restores '
      'the session and routes to home (no crash, no infinite spinner)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _seedCachedStaffSession(prefs);

    final router = await _pumpApp(tester, prefs);

    // First frame: splash spinner is visible (bootstrap in progress).
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await _drainBootstrap(tester);

    // No infinite spinner on splash: the splash is gone and we did NOT fall back
    // to the login/auth entry — the cached session restored and routed in.
    expect(find.byType(SplashScreen), findsNothing);
    final landed = router.routeInformationProvider.value.uri.path;
    expect(
      landed,
      RouteNames.admin,
      reason: 'cached super-admin session must restore to the authenticated '
          'home, not bounce to login/splash; landed on $landed',
    );
    // The authenticated landing actually rendered (no infinite spinner, no
    // crash) — the returning user got into the app offline.
    expect(find.text('admin-home-stub'), findsOneWidget);
    expect(tester.takeException(), isNull);
    _cancelScheduledRefresh(tester);
  });

  testWidgets(
      'QA-X-003 no cached session + offline → degrades to the auth entry '
      '(no crash, no infinite spinner)',
      (tester) async {
    // No prior session persisted. Cold start offline must still resolve to the
    // login / qa-login entry rather than hanging on the splash.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = await _pumpApp(tester, prefs);

    await tester.pump();
    await _drainBootstrap(tester);

    expect(find.byType(SplashScreen), findsNothing);
    final landed = router.routeInformationProvider.value.uri.path;
    expect(
      landed == RouteNames.login || landed == RouteNames.qaLogin,
      isTrue,
      reason: 'offline cold start with no cache must reach the auth entry, '
          'not hang; landed on $landed',
    );
    expect(tester.takeException(), isNull);
  });
}
