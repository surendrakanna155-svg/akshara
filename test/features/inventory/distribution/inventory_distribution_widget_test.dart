import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/inventory/distribution/inventory_distribution_screen.dart';
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
        home: const InventoryDistributionScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders KPI and distribution rows', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Inventory Distribution'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Student distributions'), findsOneWidget);
    expect(find.byKey(QaTestKeys.inventoryDistributionRow('dist_1')),
        findsOneWidget);
    expect(find.text('Mark demo distribution as distributed'), findsNothing);
  });

  testWidgets('creates a distribution from FAB dialog', (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.byKey(QaTestKeys.inventoryDistributionCreateFab));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(QaTestKeys.inventoryDistributionStudentIdField),
      'student_test_1',
    );
    await tester.enterText(
      find.byKey(QaTestKeys.inventoryDistributionCatalogItemField),
      'cat_1',
    );
    await tester.enterText(
      find.byKey(QaTestKeys.inventoryDistributionQuantityField),
      '2',
    );
    await tester.tap(
      find.byKey(QaTestKeys.inventoryDistributionCreateSubmitButton),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(QaTestKeys.inventoryDistributionCreateSuccessSnackbar),
      findsOneWidget,
    );
  });
}
