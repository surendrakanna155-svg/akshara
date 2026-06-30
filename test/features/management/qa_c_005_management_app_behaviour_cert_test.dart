import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/management/admissions/management_admissions_screen.dart';
import 'package:akshara_erp/features/management/dashboard/management_dashboard_screen.dart';
import 'package:akshara_erp/features/management/management_providers.dart';
import 'package:akshara_erp/features/management/settings/management_settings_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW7 · QA-C-005 — Principal / Management app *behaviour* certification (Batch 2).
///
/// Sits ON TOP of the existing Management widget coverage which already proves
/// rendering + states + several flows:
///   • test/features/management/management_screens_test.dart   (KPIs, export
///     button present, dashboard loading, admissions error; settings edit→save)
///   • test/features/management/management_kpi_navigation_test.dart
///   • test/features/management/management_insight_navigation_test.dart
///   • test/features/management/management_write_test.dart
///   • test/features/management/qw2_principal_write_authz_test.dart
///
/// This cert asserts the Management surface's most consequential clickable
/// behaviour — the Settings edit→dialog→save loop — actually mutates and
/// confirms (a form-validate + dialog-open + confirm), plus the canonical 4
/// async states across representative screens.
void _useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size viewport = const Size(1440, 900),
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  _useViewport(tester, viewport);
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
  group('QA-C-005 · Management app — clickable behaviour', () {
    testWidgets('Settings edit → dialog → save confirms the change',
        (tester) async {
      await _pump(tester, const ManagementSettingsScreen());

      // 1. Open the per-item edit dialog.
      await tester.tap(
        find.byKey(QaTestKeys.managementSettingsItemEditButton('school_name')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(QaTestKeys.managementSettingsDialogField),
        findsOneWidget,
      );

      // 2. Enter a new value and confirm the dialog.
      await tester.enterText(
        find.byKey(QaTestKeys.managementSettingsDialogField),
        'Akshara Leadership School',
      );
      await tester
          .tap(find.byKey(QaTestKeys.managementSettingsDialogSaveButton));
      await tester.pumpAndSettle();

      // 3. Persist via the screen-level save → confirmation surfaces.
      await tester.tap(find.byKey(QaTestKeys.managementSettingsSaveButton));
      await tester.pumpAndSettle();

      expect(find.text('Management settings saved'), findsOneWidget);
    });

    testWidgets('Dashboard export action is wired and tappable',
        (tester) async {
      await _pump(tester, const ManagementDashboardScreen());

      final exportButton =
          find.byKey(QaTestKeys.managementDashboardExportButton);
      expect(exportButton, findsOneWidget);

      // Tapping the export CTA must not throw — it opens the export affordance.
      await tester.tap(exportButton);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('QA-C-005 · Management app — canonical 4 states render', () {
    testWidgets('SUCCESS — dashboard settles into its KPI data path',
        (tester) async {
      await _pump(tester, const ManagementDashboardScreen());

      expect(find.text('Revenue (FY 2026-27)'), findsOneWidget);
      expect(find.byType(AksharaLoadingState), findsNothing);
      expect(find.byType(AksharaErrorState), findsNothing);
    });

    testWidgets('LOADING — dashboard shows AksharaLoadingState',
        (tester) async {
      await _pump(
        tester,
        const ManagementDashboardScreen(),
        overrides: [
          managementDashboardLoadingProvider.overrideWith((ref) => true),
        ],
        settle: false,
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('EMPTY — dashboard shows AksharaEmptyState', (tester) async {
      await _pump(
        tester,
        const ManagementDashboardScreen(),
        overrides: [
          managementDashboardEmptyProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });

    testWidgets('ERROR — admissions shows AksharaErrorState', (tester) async {
      await _pump(
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
