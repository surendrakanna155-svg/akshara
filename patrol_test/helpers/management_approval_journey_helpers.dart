import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import 'patrol_helpers.dart';

Future<void> approveFirstManagementItem(PatrolIntegrationTester $) async {
  const approvalId = 'appr_mg_1';
  final approveKey = QaTestKeys.managementApproveButton(approvalId);

  await assertVisibleKey($, approveKey);
  await $.tester.ensureVisible(find.byKey(approveKey));
  await $.tester.tap(find.byKey(approveKey));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.managementApprovalSuccessSnackbar);
}
