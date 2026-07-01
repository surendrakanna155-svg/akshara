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

/// Saves a draft route from Transport → Routes (screen already open).
Future<void> createTransportRouteDraft(PatrolIntegrationTester $) async {
  await assertVisibleKey($, QaTestKeys.transportSaveRouteButton);
  await _ensureKeyTapTarget($, QaTestKeys.transportSaveRouteButton);
  await $.tester.tap(find.byKey(QaTestKeys.transportSaveRouteButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  // Route name no longer pre-fills QA data — type a real name before saving.
  await $.tester.enterText(find.byType(TextField), 'Route 12 — East');
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await $(QaTestKeys.transportSaveRouteDialogButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.transportRouteSuccessSnackbar);
}

/// Activates the draft route created by [createTransportRouteDraft] (mock id `route_101`).
Future<void> activateTransportRouteDraft(
  PatrolIntegrationTester $, {
  String routeId = 'route_101',
}) async {
  final activateKey = QaTestKeys.transportActivateRouteButton(routeId);
  await assertVisibleKey($, activateKey);
  await _ensureKeyTapTarget($, activateKey);
  await $.tester.tap(find.byKey(activateKey));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await $(QaTestKeys.transportActivateRouteDialogButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.transportRouteActivatedSnackbar);
}
