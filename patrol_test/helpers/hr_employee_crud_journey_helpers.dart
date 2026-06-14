import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import 'patrol_helpers.dart';

Future<void> createHrEmployeeFromDirectory(PatrolIntegrationTester $) async {
  await assertVisibleKey($, QaTestKeys.hrCreateEmployeeButton);
  await $.tester.ensureVisible(find.byKey(QaTestKeys.hrCreateEmployeeButton));
  await $.tester.tap(find.byKey(QaTestKeys.hrCreateEmployeeButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await assertVisibleKey($, QaTestKeys.hrCreateEmployeeDialogSubmitButton);
  await $.tester.tap(find.byKey(QaTestKeys.hrCreateEmployeeDialogSubmitButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.hrEmployeeCreatedSnackbar);
}

Future<void> editHrEmployeeProfile(
  PatrolIntegrationTester $,
  String employeeId,
) async {
  final editKey = QaTestKeys.hrEditEmployeeButton(employeeId);
  await assertVisibleKey($, editKey);
  await $.tester.ensureVisible(find.byKey(editKey));
  await $.tester.tap(find.byKey(editKey));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await assertVisibleKey($, QaTestKeys.hrEditEmployeeDialogSubmitButton);
  await $.tester.tap(find.byKey(QaTestKeys.hrEditEmployeeDialogSubmitButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.hrEmployeeUpdatedSnackbar);
}

Future<void> deactivateHrEmployeeProfile(
  PatrolIntegrationTester $,
  String employeeId,
) async {
  final deactivateKey = QaTestKeys.hrDeactivateEmployeeButton(employeeId);
  await assertVisibleKey($, deactivateKey);
  await $.tester.ensureVisible(find.byKey(deactivateKey));
  await $.tester.tap(find.byKey(deactivateKey));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.hrEmployeeStatusSuccessSnackbar);
}

Future<void> activateHrEmployeeProfile(
  PatrolIntegrationTester $,
  String employeeId,
) async {
  final activateKey = QaTestKeys.hrActivateEmployeeButton(employeeId);
  await assertVisibleKey($, activateKey);
  await $.tester.ensureVisible(find.byKey(activateKey));
  await $.tester.tap(find.byKey(activateKey));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.hrEmployeeStatusSuccessSnackbar);
}
