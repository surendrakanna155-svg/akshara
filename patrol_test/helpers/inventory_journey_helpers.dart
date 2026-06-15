import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import 'patrol_helpers.dart';

Future<void> _ensureKeyTapTarget(PatrolIntegrationTester $, Key key) async {
  final finder = find.byKey(key);
  final scrollable = find.descendant(
    of: find.byType(SingleChildScrollView),
    matching: find.byType(Scrollable),
  );
  if ($.tester.any(scrollable)) {
    await $.tester.scrollUntilVisible(
      finder,
      500,
      scrollable: scrollable.first,
    );
  } else {
    await $.tester.ensureVisible(finder);
  }
  await $.pump(const Duration(milliseconds: 300));
}

/// Creates a draft PO from Inventory → Procurement (screen already open).
Future<void> createInventoryProcurementOrder(PatrolIntegrationTester $) async {
  await assertVisibleKey($, QaTestKeys.inventoryCreatePoButton);
  await _ensureKeyTapTarget($, QaTestKeys.inventoryCreatePoButton);
  await $.tester.tap(find.byKey(QaTestKeys.inventoryCreatePoButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await $('Create draft PO').tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.inventoryPoSuccessSnackbar);
}

Future<void> approveInventoryProcurementOrder(
  PatrolIntegrationTester $, {
  String orderId = 'po_4',
}) async {
  await assertVisibleKey(
      $, QaTestKeys.inventoryPoApproveHandoffButton(orderId));
  await _ensureKeyTapTarget(
      $, QaTestKeys.inventoryPoApproveHandoffButton(orderId));
  await $.tester
      .tap(find.byKey(QaTestKeys.inventoryPoApproveHandoffButton(orderId)));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await assertVisibleKey($, QaTestKeys.inventoryPoApproveHandoffDialogButton);
  await $.tester
      .tap(find.byKey(QaTestKeys.inventoryPoApproveHandoffDialogButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertSnackBarText($, 'approved', timeout: const Duration(seconds: 30));
}

Future<void> approveAndReceiveInventoryProcurementOrder(
  PatrolIntegrationTester $, {
  String orderId = 'po_4',
}) async {
  await approveInventoryProcurementOrder($, orderId: orderId);
  await $.pumpAndSettle(timeout: const Duration(seconds: 12));

  await scrollModuleBody($, 'Purchase orders', times: 4);
  await assertVisibleKey(
      $, QaTestKeys.inventoryPoReceiveHandoffButton(orderId),
      timeout: const Duration(seconds: 45));
  await _ensureKeyTapTarget(
      $, QaTestKeys.inventoryPoReceiveHandoffButton(orderId));
  await $.tester
      .tap(find.byKey(QaTestKeys.inventoryPoReceiveHandoffButton(orderId)));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await assertVisibleKey($, QaTestKeys.inventoryPoReceiveHandoffDialogButton);
  await $.tester
      .tap(find.byKey(QaTestKeys.inventoryPoReceiveHandoffDialogButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertSnackBarText($, 'Goods receipt',
      timeout: const Duration(seconds: 30));
}
