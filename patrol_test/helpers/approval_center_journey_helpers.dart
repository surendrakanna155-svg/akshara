import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import 'patrol_helpers.dart';

/// Opens principal approval center; optionally switches persona after a submit step.
Future<void> openPrincipalApprovalCenter(
  PatrolIntegrationTester $, {
  Key? categoryFilterKey,
  bool pendingOnly = true,
  bool switchFromCurrentPersona = false,
}) async {
  if (switchFromCurrentPersona) {
    await switchQaPersona($, QaLoginPersona.principal);
  }
  await goToErpRoute($, RouteNames.managementApprovals);
  await waitForLoadingToClear($);
  await assertVisibleKey($, QaTestKeys.approvalCenterScreen);
  if (pendingOnly) {
    await scrollTap($, 'Pending');
  }
  if (categoryFilterKey != null) {
    await tapByKey($, categoryFilterKey);
  }
}

/// Approves the pending mobile card (or desktop row) matching [titleSubstring].
Future<void> approvePendingRequestWithTitle(
  PatrolIntegrationTester $,
  String titleSubstring,
) async {
  await scrollModuleBody($, titleSubstring, times: 6);
  await assertVisibleText($, titleSubstring);

  final titleFinder = find.textContaining(titleSubstring);
  final cardFinder = find.ancestor(
    of: titleFinder,
    matching: find.byType(Card),
  );
  final inlineApprove = find.descendant(
    of: cardFinder,
    matching: find.widgetWithText(FilledButton, 'Approve'),
  );

  if ($.tester.any(inlineApprove)) {
    await $.tester.ensureVisible(inlineApprove.first);
    await $.tester.tap(inlineApprove.first);
  } else {
    await scrollTap($, titleSubstring);
    await $.pumpAndSettle(timeout: const Duration(seconds: 8));
    await scrollTap($, 'Approve');
  }
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.managementApprovalSuccessSnackbar);
}

/// Finance submit → principal approval center approve.
Future<void> principalApproveFromFinanceSubmit(
  PatrolIntegrationTester $, {
  required Key categoryFilterKey,
  required String titleSubstring,
}) async {
  await openPrincipalApprovalCenter(
    $,
    categoryFilterKey: categoryFilterKey,
    switchFromCurrentPersona: true,
  );
  await approvePendingRequestWithTitle($, titleSubstring);
}
