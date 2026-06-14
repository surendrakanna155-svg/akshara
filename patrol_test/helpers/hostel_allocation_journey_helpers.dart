import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import 'patrol_helpers.dart';

Future<void> assignHostelRoomForStudent(
  PatrolIntegrationTester $,
  String studentId,
) async {
  final assignKey = QaTestKeys.hostelAssignStudentButton(studentId);
  await assertVisibleKey($, assignKey);
  await $.tester.ensureVisible(find.byKey(assignKey));
  await $.tester.tap(find.byKey(assignKey));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await assertVisibleKey($, QaTestKeys.hostelAssignDialogSubmitButton);
  await $.tester.tap(find.byKey(QaTestKeys.hostelAssignDialogSubmitButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.hostelAssignSuccessSnackbar);
}

Future<void> checkoutHostelStudentRow(
  PatrolIntegrationTester $,
  String studentId,
) async {
  final checkoutKey = QaTestKeys.hostelCheckoutStudentButton(studentId);
  await assertVisibleKey($, checkoutKey);
  await $.tester.ensureVisible(find.byKey(checkoutKey));
  await $.tester.tap(find.byKey(checkoutKey));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await assertVisibleKey($, QaTestKeys.hostelCheckoutDialogSubmitButton);
  await $.tester.tap(find.byKey(QaTestKeys.hostelCheckoutDialogSubmitButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.hostelCheckoutSuccessSnackbar);
}
