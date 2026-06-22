import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/inventory/distribution/inventory_replacement_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
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
        home: const InventoryReplacementScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders pending replacement and approves request', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Replacement Workflow'), findsOneWidget);
    expect(find.byKey(QaTestKeys.inventoryReplacementRow('rpl_1')),
        findsOneWidget);

    await tester.tap(
      find.byKey(QaTestKeys.inventoryReplacementApproveButton('rpl_1')),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();

    expect(
      find.byKey(QaTestKeys.inventoryReplacementApproveSuccessSnackbar),
      findsOneWidget,
    );
  });
}
