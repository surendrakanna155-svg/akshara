import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/management/academics/management_academics_screen.dart';
import 'package:akshara_erp/features/management/admissions/management_admissions_screen.dart';
import 'package:akshara_erp/features/management/analytics/management_analytics_screen.dart';
import 'package:akshara_erp/features/management/dashboard/management_dashboard_screen.dart';
import 'package:akshara_erp/features/management/finance/management_finance_screen.dart';
import 'package:akshara_erp/features/management/management_providers.dart';
import 'package:akshara_erp/features/management/performance/management_performance_screen.dart';
import 'package:akshara_erp/features/management/settings/management_settings_screen.dart';
import 'package:akshara_erp/features/management/tasks/management_tasks_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_helpers.dart';
import 'approval/approval_center_test_helpers.dart';

void useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> pumpManagementScreen(
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
  group('Management screens — desktop', () {
    testWidgets('ManagementDashboardScreen renders KPIs', (tester) async {
      await pumpManagementScreen(tester, const ManagementDashboardScreen());

      expect(find.text('Revenue (FY 2026-27)'), findsOneWidget);
      expect(find.text('Approval queue'), findsOneWidget);
    });

    testWidgets('ManagementDashboardScreen export button is present', (
      tester,
    ) async {
      await pumpManagementScreen(tester, const ManagementDashboardScreen());
      expect(
        find.byKey(QaTestKeys.managementDashboardExportButton),
        findsOneWidget,
      );
    });

    testWidgets('ManagementDashboardScreen shows loading state',
        (tester) async {
      useViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            managementDashboardLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ManagementDashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('ManagementAnalyticsScreen renders class summary', (
      tester,
    ) async {
      await pumpManagementScreen(tester, const ManagementAnalyticsScreen());

      expect(find.text('Class summary'), findsOneWidget);
      expect(find.text('Total Students'), findsOneWidget);
    });

    testWidgets('ManagementAdmissionsScreen renders funnel', (tester) async {
      await pumpManagementScreen(tester, const ManagementAdmissionsScreen());

      expect(find.text('Funnel stages'), findsOneWidget);
      expect(find.text('Leads (MTD)'), findsOneWidget);
    });

    testWidgets('ManagementFinanceScreen renders drill-down', (tester) async {
      await pumpManagementScreen(tester, const ManagementFinanceScreen());

      expect(find.text('Finance module drill-down'), findsOneWidget);
      expect(find.text('Fee Collected (MTD)'), findsOneWidget);
    });

    testWidgets('ManagementAcademicsScreen renders subjects', (tester) async {
      await pumpManagementScreen(tester, const ManagementAcademicsScreen());

      expect(find.text('Subject performance'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
    });

    testWidgets('ManagementPerformanceScreen renders table', (tester) async {
      await pumpManagementScreen(tester, const ManagementPerformanceScreen());

      expect(find.text('Class performance'), findsOneWidget);
      expect(find.text('10-A'), findsWidgets);
    });

    testWidgets('ManagementTasksScreen renders approval queue', (tester) async {
      await pumpApprovalCenter(tester);

      expect(find.text('Approval queue'), findsOneWidget);
      expect(find.text('Science lab upgrade — Q3 budget'), findsOneWidget);
    });

    testWidgets('ManagementSettingsScreen renders sections', (tester) async {
      await pumpManagementScreen(tester, const ManagementSettingsScreen());

      expect(find.text('Management settings'), findsOneWidget);
      expect(find.text('School profile'), findsOneWidget);
    });

    testWidgets('ManagementSettingsScreen allows editing and save',
        (tester) async {
      await pumpManagementScreen(tester, const ManagementSettingsScreen());

      await tester.tap(
        find.byKey(QaTestKeys.managementSettingsItemEditButton('school_name')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(QaTestKeys.managementSettingsDialogField),
        'Akshara Leadership School',
      );
      await tester
          .tap(find.byKey(QaTestKeys.managementSettingsDialogSaveButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(QaTestKeys.managementSettingsSaveButton));
      await tester.pumpAndSettle();

      expect(find.text('Management settings saved'), findsOneWidget);
    });
  });

  group('Management screens — mobile', () {
    testWidgets('ManagementTasksScreen renders on mobile', (tester) async {
      await pumpApprovalCenter(
        tester,
        viewport: const Size(390, 844),
      );

      expect(find.text('Pending'), findsWidgets);
    });

    testWidgets('ManagementAdmissionsScreen shows error state', (tester) async {
      await pumpManagementScreen(
        tester,
        const ManagementAdmissionsScreen(),
        viewport: const Size(390, 844),
        overrides: [
          managementAdmissionsErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
