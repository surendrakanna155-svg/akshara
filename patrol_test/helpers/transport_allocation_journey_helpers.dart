import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import 'patrol_helpers.dart';

Future<void> assignStudentTransportRow(
  PatrolIntegrationTester $,
  String allocationId,
) async {
  final assignKey = QaTestKeys.transportAssignStudentButton(allocationId);
  await assertVisibleKey($, assignKey);
  await $.tester.ensureVisible(find.byKey(assignKey));
  await $.tester.tap(find.byKey(assignKey));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await assertVisibleKey($, QaTestKeys.transportAssignDialogSubmitButton);
  await $.tester.tap(find.byKey(QaTestKeys.transportAssignDialogSubmitButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.transportAssignSuccessSnackbar);
}

Future<void> transferStudentTransportRow(
  PatrolIntegrationTester $,
  String allocationId,
) async {
  final transferKey = QaTestKeys.transportTransferStudentButton(allocationId);
  await assertVisibleKey($, transferKey);
  await $.tester.ensureVisible(find.byKey(transferKey));
  await $.tester.tap(find.byKey(transferKey));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await assertVisibleKey($, QaTestKeys.transportTransferDialogSubmitButton);
  await $.tester.tap(find.byKey(QaTestKeys.transportTransferDialogSubmitButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.transportTransferSuccessSnackbar);
}

Future<void> removeStudentTransportRow(
  PatrolIntegrationTester $,
  String allocationId,
) async {
  final removeKey = QaTestKeys.transportRemoveStudentButton(allocationId);
  await assertVisibleKey($, removeKey);
  await $.tester.ensureVisible(find.byKey(removeKey));
  await $.tester.tap(find.byKey(removeKey));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await assertVisibleKey($, QaTestKeys.transportRemoveDialogSubmitButton);
  await $.tester.tap(find.byKey(QaTestKeys.transportRemoveDialogSubmitButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.transportRemoveSuccessSnackbar);
}
