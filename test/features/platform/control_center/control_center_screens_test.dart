import 'package:akshara_erp/features/platform/control_center/analytics/control_center_analytics_screen.dart';
import 'package:akshara_erp/features/platform/control_center/billing/control_center_billing_screen.dart';
import 'package:akshara_erp/features/platform/control_center/crm/control_center_crm_screen.dart';
import 'package:akshara_erp/features/platform/control_center/dashboard/control_center_dashboard_screen.dart';
import 'package:akshara_erp/features/platform/control_center/monitoring/control_center_monitoring_screen.dart';
import 'package:akshara_erp/features/platform/control_center/roles/control_center_roles_screen.dart';
import 'package:akshara_erp/features/platform/control_center/schools/control_center_schools_screen.dart';
import 'package:akshara_erp/features/platform/control_center/settings/control_center_settings_screen.dart';
import 'package:akshara_erp/features/platform/control_center/subscriptions/control_center_subscriptions_screen.dart';
import 'package:akshara_erp/features/platform/control_center/success/control_center_success_screen.dart';
import 'package:akshara_erp/features/platform/control_center/support/control_center_support_screen.dart';
import 'package:akshara_erp/features/platform/control_center/white_label/control_center_white_label_screen.dart';
import 'package:akshara_erp/features/platform/control_center/control_center_models.dart';
import 'package:akshara_erp/features/platform/control_center/control_center_providers.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../test_helpers.dart';

void useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> pumpControlCenterScreen(
  WidgetTester tester,
  Widget screen, {
  Size viewport = const Size(1440, 900),
  List<Override> overrides = const [],
}) async {
  useViewport(tester, viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('Control Center screens — desktop', () {
    testWidgets('ControlCenterDashboardScreen renders KPIs and PII banner', (
      tester,
    ) async {
      await pumpControlCenterScreen(
        tester,
        const ControlCenterDashboardScreen(),
      );

      expect(find.text('Total Schools'), findsOneWidget);
      expect(find.text('ERP module adoption'), findsOneWidget);
      expect(find.text(kControlCenterPiiBannerMessage), findsOneWidget);
    });

    testWidgets('ControlCenterDashboardScreen shows loading state', (
      tester,
    ) async {
      useViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            controlCenterDashboardLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ControlCenterDashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('ControlCenterSchoolsScreen renders schools registry', (
      tester,
    ) async {
      await pumpControlCenterScreen(
        tester,
        const ControlCenterSchoolsScreen(),
      );

      expect(find.text('Schools registry'), findsOneWidget);
      expect(find.text('SCH-1001'), findsOneWidget);
    });

    testWidgets('ControlCenterSubscriptionsScreen renders plans', (
      tester,
    ) async {
      await pumpControlCenterScreen(
        tester,
        const ControlCenterSubscriptionsScreen(),
      );

      expect(find.text('Subscription plans'), findsOneWidget);
      expect(find.text('STANDARD'), findsOneWidget);
    });

    testWidgets('ControlCenterBillingScreen renders revenue', (tester) async {
      await pumpControlCenterScreen(
        tester,
        const ControlCenterBillingScreen(),
      );

      expect(find.text('Platform revenue'), findsOneWidget);
      expect(find.text('Recent invoices'), findsOneWidget);
    });

    testWidgets('ControlCenterCrmScreen renders sales pipeline', (
      tester,
    ) async {
      await pumpControlCenterScreen(
        tester,
        const ControlCenterCrmScreen(),
      );

      expect(find.text('Sales pipeline'), findsOneWidget);
      expect(find.text('Lotus Valley School'), findsOneWidget);
    });

    testWidgets('ControlCenterSupportScreen renders tickets', (tester) async {
      await pumpControlCenterScreen(
        tester,
        const ControlCenterSupportScreen(),
      );

      expect(find.text('Support tickets'), findsOneWidget);
      expect(find.text('TKT-8801'), findsOneWidget);
    });

    testWidgets('ControlCenterSuccessScreen renders CS data', (tester) async {
      await pumpControlCenterScreen(
        tester,
        const ControlCenterSuccessScreen(),
      );

      expect(find.text('Customer success'), findsOneWidget);
      expect(find.text('Heritage Convent — Pune'), findsOneWidget);
    });

    testWidgets('ControlCenterWhiteLabelScreen renders configs', (
      tester,
    ) async {
      await pumpControlCenterScreen(
        tester,
        const ControlCenterWhiteLabelScreen(),
      );

      expect(find.text('White label configurations'), findsOneWidget);
      expect(find.text('Sunrise Academy — Bengaluru'), findsOneWidget);
    });

    testWidgets('ControlCenterAnalyticsScreen renders analytics', (
      tester,
    ) async {
      await pumpControlCenterScreen(
        tester,
        const ControlCenterAnalyticsScreen(),
      );

      expect(find.text('Platform analytics'), findsOneWidget);
      expect(find.text('ERP module usage'), findsOneWidget);
    });

    testWidgets('ControlCenterMonitoringScreen renders services', (
      tester,
    ) async {
      await pumpControlCenterScreen(
        tester,
        const ControlCenterMonitoringScreen(),
      );

      expect(find.text('Platform monitoring'), findsOneWidget);
      expect(find.text('API Gateway'), findsOneWidget);
    });

    testWidgets('ControlCenterRolesScreen renders roles', (tester) async {
      await pumpControlCenterScreen(
        tester,
        const ControlCenterRolesScreen(),
      );

      expect(find.text('Platform roles'), findsOneWidget);
      expect(find.text('Super Admin'), findsOneWidget);
    });

    testWidgets('ControlCenterSettingsScreen renders settings', (
      tester,
    ) async {
      await pumpControlCenterScreen(
        tester,
        const ControlCenterSettingsScreen(),
      );

      expect(find.text('Platform settings'), findsOneWidget);
      expect(find.text('Multi-school architecture'), findsOneWidget);
    });
  });
}
