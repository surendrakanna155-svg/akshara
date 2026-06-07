import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/splash_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/auth_test_overrides.dart';
import 'helpers/provider_test_overrides.dart';

/// Default mobile viewport matching ST-01 / TA-01 design width.
const Size kMobileTestViewport = Size(428, 926);

/// Applies a mobile-sized test surface and resets it after the test.
void useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = kMobileTestViewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Pumps a [GoRouter] with Akshara theme + Riverpod overrides for widget tests.
Future<void> pumpAksharaRouter(
  WidgetTester tester, {
  required GoRouter router,
  SharedPreferences? prefs,
  AuthState? authOverride,
  bool settleSplash = true,
}) async {
  useMobileViewport(tester);
  SharedPreferences.setMockInitialValues({});
  final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(resolvedPrefs),
        if (authOverride != null) authStateOverride(authOverride),
        ...providerTestOverrides(),
      ],
      child: MaterialApp.router(
        theme: AksharaAppTheme.light(),
        routerConfig: router,
      ),
    ),
  );

  if (settleSplash) {
    await tester.pump();
    await tester.pump(SplashScreen.splashDuration);
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
