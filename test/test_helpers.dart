import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/auth_test_overrides.dart';
import 'helpers/provider_test_overrides.dart';

// Re-export so ERP widget tests that render network-backed widgets (which reach
// dioProvider → SharedPreferences) can initialize the test prefs stack via
// pumpHrScreen-style helpers without importing the helpers path directly.
export 'helpers/provider_test_overrides.dart' show initProviderTestPrefs;

/// Default mobile viewport matching ST-01 / TA-01 design width.
const Size kMobileTestViewport = Size(428, 926);

/// How far widget tests advance the clock to get past app bootstrap.
///
/// Bootstrap has two independent pending timers: the splash screen's
/// anti-flicker floor, and the startup connectivity probe
/// (`ConnectivityServiceImpl.isReachable`, a 2s timeout that never resolves
/// under the test harness). This value must cover BOTH, or the test ends with
/// a pending timer and fails.
///
/// Deliberately NOT `SplashScreen.splashDuration`. Tests used to reuse that
/// constant, which silently coupled them to a product timing decision: they
/// only passed because the splash floor happened to be 2s and therefore
/// happened to also drain the 2s connectivity timeout. Shortening the splash —
/// a pure startup-performance win — broke them for a reason that had nothing to
/// do with the splash. Sizing the settle window to the slowest bootstrap timer
/// keeps the two independent.
const Duration kStartupSettleDuration = Duration(seconds: 3);

/// Applies a mobile-sized test surface and resets it after the test.
void useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = kMobileTestViewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Pumps a [GoRouter] with NIKSHA theme + Riverpod overrides for widget tests.
Future<void> pumpAksharaRouter(
  WidgetTester tester, {
  required GoRouter router,
  SharedPreferences? prefs,
  AuthState? authOverride,
  bool settleSplash = true,
  List<Override> overrides = const [],
}) async {
  useMobileViewport(tester);
  SharedPreferences.setMockInitialValues({});
  final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();

  await initProviderTestPrefs();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(resolvedPrefs),
        environmentProvider.overrideWith(
          (ref) => Environment.development.copyWith(enableQaLogin: true),
        ),
        if (authOverride != null) authStateOverride(authOverride),
        ...providerTestOverrides(),
        ...overrides,
      ],
      child: MaterialApp.router(
        theme: AksharaAppTheme.light(),
        routerConfig: router,
      ),
    ),
  );

  if (settleSplash) {
    await tester.pump();
    await tester.pump(kStartupSettleDuration);
    await tester.pump();
  }
}

/// Default Riverpod overrides for ERP module widget tests.
List<Override> erpWidgetTestOverrides([List<Override> extra = const []]) =>
    providerTestOverrides([
      authStateOverride(erpWidgetTestStaffAuth()),
      ...extra,
    ]);

/// Allows Riverpod [FutureProvider] microtasks to complete in widget tests.
Future<void> settleRiverpodFutures(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  });
  await tester.pump();
  await tester.pump();
}
