import 'package:akshara_erp/features/platform/control_center/analytics/control_center_analytics_screen.dart';
import 'package:akshara_erp/features/platform/control_center/billing/control_center_billing_screen.dart';
import 'package:akshara_erp/features/platform/control_center/control_center_providers.dart';
import 'package:akshara_erp/features/platform/control_center/crm/control_center_crm_screen.dart';
import 'package:akshara_erp/features/platform/control_center/dashboard/control_center_dashboard_screen.dart';
import 'package:akshara_erp/features/platform/control_center/features/control_center_features_screen.dart';
import 'package:akshara_erp/features/platform/control_center/monitoring/control_center_monitoring_screen.dart';
import 'package:akshara_erp/features/platform/control_center/providers/control_center_providers_screen.dart';
import 'package:akshara_erp/features/platform/control_center/roles/control_center_roles_screen.dart';
import 'package:akshara_erp/features/platform/control_center/schools/control_center_schools_screen.dart';
import 'package:akshara_erp/features/platform/control_center/settings/control_center_settings_screen.dart';
import 'package:akshara_erp/features/platform/control_center/subscriptions/control_center_subscriptions_screen.dart';
import 'package:akshara_erp/features/platform/control_center/success/control_center_success_screen.dart';
import 'package:akshara_erp/features/platform/control_center/support/control_center_support_screen.dart';
import 'package:akshara_erp/features/platform/control_center/white_label/control_center_white_label_screen.dart';
import 'package:akshara_erp/features/platform/control_center/widgets/control_center_module_scaffold.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_loading_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// Tolerates Flutter's debug-only "ListTile background color or ink splashes may
/// be invisible" paint diagnostic. It is a visual-quality lint (a ListTile sits
/// inside a DecoratedBox with a bg colour) with no functional impact and no
/// production crash — it must not fail a render smoke test. Mirrors the
/// `suppressGoldenOverflowErrors` precedent in test/golden/golden_test_helpers.dart.
void _tolerateListTilePaintDiagnostic() {
  final previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains(
        'ListTile background color or ink splashes may be invisible')) {
      return;
    }
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// QW3 · QA-F-058 — Control Center 15 sub-screen renders + empty/error states.
/// Every ACC-01..ACC-15 sub-screen was 0% lcov / never pumped. This table-driven
/// suite pumps each screen (super-admin demo data via `RepositoryQuery.demo`),
/// asserts the success render through `ControlCenterModuleScaffold`, and forces the
/// loading + error states for the 12 screens that expose manual state hooks.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  // Control center is a wide admin surface; use a tablet width so its desktop
  // layout (KPI grids, two-column charts) lays out without spurious overflow.
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  if (settle) {
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  // Screens that expose manual loading/error StateProviders we can force.
  final stateHookCases = <({
    String label,
    Widget screen,
    StateProvider<bool> loading,
    StateProvider<bool> error,
  })>[
    (
      label: 'Dashboard',
      screen: const ControlCenterDashboardScreen(),
      loading: controlCenterDashboardLoadingProvider,
      error: controlCenterDashboardErrorProvider,
    ),
    (
      label: 'Schools',
      screen: const ControlCenterSchoolsScreen(),
      loading: controlCenterSchoolsLoadingProvider,
      error: controlCenterSchoolsErrorProvider,
    ),
    (
      label: 'Subscriptions',
      screen: const ControlCenterSubscriptionsScreen(),
      loading: controlCenterSubscriptionsLoadingProvider,
      error: controlCenterSubscriptionsErrorProvider,
    ),
    (
      label: 'Billing',
      screen: const ControlCenterBillingScreen(),
      loading: controlCenterBillingLoadingProvider,
      error: controlCenterBillingErrorProvider,
    ),
    (
      label: 'CRM',
      screen: const ControlCenterCrmScreen(),
      loading: controlCenterCrmLoadingProvider,
      error: controlCenterCrmErrorProvider,
    ),
    (
      label: 'Support',
      screen: const ControlCenterSupportScreen(),
      loading: controlCenterSupportLoadingProvider,
      error: controlCenterSupportErrorProvider,
    ),
    (
      label: 'Success',
      screen: const ControlCenterSuccessScreen(),
      loading: controlCenterSuccessLoadingProvider,
      error: controlCenterSuccessErrorProvider,
    ),
    (
      label: 'White Label',
      screen: const ControlCenterWhiteLabelScreen(),
      loading: controlCenterWhiteLabelLoadingProvider,
      error: controlCenterWhiteLabelErrorProvider,
    ),
    (
      label: 'Analytics',
      screen: const ControlCenterAnalyticsScreen(),
      loading: controlCenterAnalyticsLoadingProvider,
      error: controlCenterAnalyticsErrorProvider,
    ),
    (
      label: 'Monitoring',
      screen: const ControlCenterMonitoringScreen(),
      loading: controlCenterMonitoringLoadingProvider,
      error: controlCenterMonitoringErrorProvider,
    ),
    (
      label: 'Roles',
      screen: const ControlCenterRolesScreen(),
      loading: controlCenterRolesLoadingProvider,
      error: controlCenterRolesErrorProvider,
    ),
    (
      label: 'Settings',
      screen: const ControlCenterSettingsScreen(),
      loading: controlCenterSettingsLoadingProvider,
      error: controlCenterSettingsErrorProvider,
    ),
  ];

  group('QA-F-058 · ControlCenter sub-screens', () {
    for (final c in stateHookCases) {
      testWidgets('${c.label} renders the control center scaffold',
          (tester) async {
        await _pump(tester, c.screen);

        expect(find.byType(ControlCenterModuleScaffold), findsOneWidget);
        // Breadcrumb trail ends with the active screen label.
        expect(find.text(c.label), findsWidgets);
      });

      testWidgets('${c.label} shows the loading state when forced',
          (tester) async {
        await _pump(
          tester,
          c.screen,
          overrides: [c.loading.overrideWith((ref) => true)],
          settle: false,
        );

        expect(find.byType(ControlCenterModuleScaffold), findsOneWidget);
        expect(find.byType(AksharaLoadingState), findsWidgets);
      });

      testWidgets('${c.label} shows the error state when forced',
          (tester) async {
        await _pump(
          tester,
          c.screen,
          overrides: [c.error.overrideWith((ref) => true)],
        );

        expect(find.byType(ControlCenterModuleScaffold), findsOneWidget);
        expect(find.byType(AksharaErrorState), findsWidgets);
      });
    }

    // Providers + Features read the Future directly (.when) — no manual hooks,
    // so we cover the success render path only.
    testWidgets('Providers renders the configure-provider surface',
        (tester) async {
      await _pump(tester, const ControlCenterProvidersScreen());

      expect(find.byType(ControlCenterModuleScaffold), findsOneWidget);
      expect(find.text('Providers'), findsWidgets);
    });

    testWidgets('Features renders the feature-enablement surface',
        (tester) async {
      _tolerateListTilePaintDiagnostic();
      await _pump(tester, const ControlCenterFeaturesScreen());

      expect(find.byType(ControlCenterModuleScaffold), findsOneWidget);
      expect(find.text('Features'), findsWidgets);
    });
  });
}
