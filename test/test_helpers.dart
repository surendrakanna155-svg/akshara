import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/features/auth/splash_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool settleSplash = true,
}) async {
  useMobileViewport(tester);
  SharedPreferences.setMockInitialValues({});
  final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(resolvedPrefs),
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
