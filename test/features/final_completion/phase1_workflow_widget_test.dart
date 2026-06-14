import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/education/education_screen.dart';
import 'package:akshara_erp/features/hr/payroll/hr_payroll_screen.dart';
import 'package:akshara_erp/features/inventory/intelligence/inventory_lifecycle_screen.dart';
import 'package:akshara_erp/features/inventory/procurement/inventory_procurement_screen.dart';
import 'package:akshara_erp/features/transport/routes/transport_routes_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> extra = const [],
}) async {
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
        ...extra,
      ]),
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
  group('Phase 1 workflow widgets — QA keys present', () {
    testWidgets('HR payroll process button and dialog cancel', (tester) async {
      await _pump(tester, const HrPayrollScreen());
      expect(find.byKey(QaTestKeys.hrProcessPayrollButton), findsOneWidget);

      await tester.tap(find.byKey(QaTestKeys.hrProcessPayrollButton));
      await tester.pumpAndSettle();
      expect(find.text('Process payroll run'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Process payroll run'), findsNothing);
    });

    testWidgets('Inventory procurement create PO button visible', (tester) async {
      await _pump(tester, const InventoryProcurementScreen());
      expect(find.byKey(QaTestKeys.inventoryCreatePoButton), findsOneWidget);
    });

    testWidgets('Inventory lifecycle record event button visible', (tester) async {
      await _pump(tester, const InventoryLifecycleScreen());
      expect(find.byKey(QaTestKeys.inventoryRecordLifecycleButton), findsOneWidget);
      expect(find.byKey(QaTestKeys.inventoryLifecycleScreen), findsOneWidget);
    });

    testWidgets('Transport routes new route and activate draft buttons visible', (
      tester,
    ) async {
      await _pump(tester, const TransportRoutesScreen());
      expect(find.byKey(QaTestKeys.transportSaveRouteButton), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.transportActivateRouteButton('route_15')),
        findsOneWidget,
      );
    });

    testWidgets('Education remark publish button after generate', (tester) async {
      await _pump(tester, const EducationScreen());
      await tester.tap(find.text('Report Remarks'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate remark'));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.educationPublishRemarkButton), findsOneWidget);
    });
  });
}
