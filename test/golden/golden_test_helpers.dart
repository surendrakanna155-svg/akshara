import 'package:akshara_erp/features/finance/dashboard/finance_dashboard_provider.dart';
import 'package:akshara_erp/features/inventory/inventory_providers.dart';
import 'package:akshara_erp/features/management/management_providers.dart';
import 'package:akshara_erp/features/intelligence/management/intelligence_provider.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_provider.dart';
import 'package:akshara_erp/features/student_app/dashboard/student_dashboard_provider.dart';
import 'package:akshara_erp/features/teacher/dashboard/teacher_dashboard_provider.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/provider_test_overrides.dart';
import '../test_helpers.dart';

/// Suppresses layout overflow noise during golden capture (test-only).
void suppressGoldenOverflowErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    if (message.contains('overflowed')) {
      return;
    }
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// Canonical golden test viewports (width × height, DPR 1.0).
abstract final class GoldenViewports {
  static const Size mobile390 = Size(390, 844);
  static const Size mobile428 = Size(428, 926);
  static const Size tablet834 = Size(834, 1194);

  static const List<({String label, Size size})> all = [
    (label: '390x844', size: mobile390),
    (label: '428x926', size: mobile428),
    (label: '834x1194', size: tablet834),
  ];
}

/// Applies a fixed viewport for deterministic golden captures.
void useGoldenViewport(WidgetTester tester, Size viewport) {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Pumps a dashboard screen with stable mock providers (no loading, no network).
Future<void> pumpGoldenDashboard(
  WidgetTester tester, {
  required Widget screen,
  required Size viewport,
  List<Override> extraOverrides = const [],
  bool dark = false,
  Color? personaAccent,
}) async {
  suppressGoldenOverflowErrors();
  useGoldenViewport(tester, viewport);
  await initProviderTestPrefs();

  // When a [personaAccent] is given, render the screen under the persona theme
  // the real shell applies (persona-cohesive hero + accent chrome) rather than
  // the base light/dark theme — so the golden reflects what the user sees.
  final theme = personaAccent != null
      ? AksharaAppTheme.persona(
          brightness: dark ? Brightness.dark : Brightness.light,
          accent: personaAccent,
        )
      : (dark ? AksharaAppTheme.dark() : AksharaAppTheme.light());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        parentDashboardLoadingProvider.overrideWith((ref) => false),
        teacherDashboardLoadingProvider.overrideWith((ref) => false),
        studentDashboardLoadingProvider.overrideWith((ref) => false),
        ...providerTestOverrides(extraOverrides),
      ],
      child: MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: screen,
      ),
    ),
  );

  await settleRiverpodFutures(tester);
  await tester.pump();
}

String goldenFileName(String prefix, String viewportLabel) =>
    'goldens/${prefix}_$viewportLabel.png';

/// Pumps an ERP module screen with stable mock providers.
Future<void> pumpGoldenErpScreen(
  WidgetTester tester, {
  required Widget screen,
  required Size viewport,
  List<Override> extraOverrides = const [],
  bool dark = false,
}) async {
  suppressGoldenOverflowErrors();
  useGoldenViewport(tester, viewport);
  await initProviderTestPrefs();

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => screen,
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        parentDashboardLoadingProvider.overrideWith((ref) => false),
        teacherDashboardLoadingProvider.overrideWith((ref) => false),
        studentDashboardLoadingProvider.overrideWith((ref) => false),
        managementDashboardLoadingProvider.overrideWith((ref) => false),
        financeDashboardLoadingProvider.overrideWith((ref) => false),
        inventoryDashboardLoadingProvider.overrideWith((ref) => false),
        intelligenceCanViewProvider.overrideWith((ref) => true),
        ...extraOverrides,
      ]),
      child: MaterialApp.router(
        theme: dark ? AksharaAppTheme.dark() : AksharaAppTheme.light(),
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );

  await settleRiverpodFutures(tester);
  await tester.pump();
}
