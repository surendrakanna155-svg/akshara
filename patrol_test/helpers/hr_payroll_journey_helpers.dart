import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import 'patrol_helpers.dart';

Future<void> processHrPayrollRun(PatrolIntegrationTester $) async {
  await assertVisibleKey($, QaTestKeys.hrProcessPayrollButton);
  await $.tester.ensureVisible(find.byKey(QaTestKeys.hrProcessPayrollButton));
  await $.tester.tap(find.byKey(QaTestKeys.hrProcessPayrollButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await $('Process').tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.hrPayrollProcessedSnackbar);
}
