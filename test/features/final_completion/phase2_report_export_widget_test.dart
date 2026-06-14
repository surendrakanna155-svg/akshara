import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/education/education_screen.dart';
import 'package:akshara_erp/features/hr/payroll/hr_payroll_screen.dart';
import 'package:akshara_erp/features/inventory/reports/inventory_reports_screen.dart';
import 'package:akshara_erp/features/transport/reports/transport_reports_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(ErpRole.superAdmin),
        ),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(body: screen),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

Future<void> _pumpEducation(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(ErpRole.superAdmin),
        ),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const EducationScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('Phase 2 report export widgets', () {
    testWidgets('HR payroll export PDF shows success snackbar', (tester) async {
      await _pump(tester, const HrPayrollScreen());
      expect(find.byKey(QaTestKeys.hrPayrollExportPdfButton), findsOneWidget);
      await _tapKey(tester, QaTestKeys.hrPayrollExportPdfButton);
      expect(find.byKey(QaTestKeys.hrPayrollExportSuccessSnackbar), findsOneWidget);
    });

    testWidgets('Inventory reports export PDF shows success snackbar', (
      tester,
    ) async {
      await _pump(tester, const InventoryReportsScreen());
      expect(find.byKey(QaTestKeys.inventoryReportExportPdfButton), findsOneWidget);
      await _tapKey(tester, QaTestKeys.inventoryReportExportPdfButton);
      expect(find.byKey(QaTestKeys.inventoryReportExportSuccessSnackbar), findsOneWidget);
    });

    testWidgets('Transport reports export PDF shows success snackbar', (
      tester,
    ) async {
      await _pump(tester, const TransportReportsScreen());
      expect(find.byKey(QaTestKeys.transportReportExportPdfButton), findsOneWidget);
      await _tapKey(tester, QaTestKeys.transportReportExportPdfButton);
      expect(find.byKey(QaTestKeys.transportReportExportSuccessSnackbar), findsOneWidget);
    });

    testWidgets('Education published remark shows export PDF action', (
      tester,
    ) async {
      await _pumpEducation(tester);
      await tester.tap(find.text('Report Remarks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate remark'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(QaTestKeys.educationPublishRemarkButton));
      await tester.pumpAndSettle();
      expect(find.text('Export PDF'), findsOneWidget);
      final exportButton = find.byKey(QaTestKeys.educationReportCardExportButton);
      await tester.ensureVisible(exportButton);
      ScaffoldMessenger.of(tester.element(find.byType(EducationScreen))).clearSnackBars();
      await tester.pump();
      await tester.tap(exportButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(QaTestKeys.educationReportCardExportSuccessSnackbar), findsOneWidget);
    });
  });
}
