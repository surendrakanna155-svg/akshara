import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

Future<void> recordInventoryLifecycleEvent(PatrolIntegrationTester $) async {
  await assertVisibleKey($, QaTestKeys.inventoryRecordLifecycleButton);
  await $.tester.ensureVisible(find.byKey(QaTestKeys.inventoryRecordLifecycleButton));
  await $.tester.tap(find.byKey(QaTestKeys.inventoryRecordLifecycleButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await $('Record').tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.inventoryLifecycleSuccessSnackbar);
}

void main() {
  patrolTest(
    'journey: inventory lifecycle event E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.inventoryLifecycle);
      await assertVisibleKey($, QaTestKeys.inventoryLifecycleScreen);
      await recordInventoryLifecycleEvent($);
    },
  );
}
