import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/inventory/procurement/inventory_procurement_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void main() {
  testWidgets('Ordered PO record receipt handoff shows success snackbar', (
    tester,
  ) async {
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
          home: const InventoryProcurementScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();

    final handoffButton = find.byKey(
      QaTestKeys.inventoryPoReceiveHandoffButton('po_1'),
    );
    expect(handoffButton, findsOneWidget);

    await tester.ensureVisible(handoffButton);
    await tester.tap(handoffButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(QaTestKeys.inventoryPoReceiveHandoffDialogButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(QaTestKeys.inventoryPoReceiveHandoffSuccessSnackbar),
      findsOneWidget,
    );
  });
}
