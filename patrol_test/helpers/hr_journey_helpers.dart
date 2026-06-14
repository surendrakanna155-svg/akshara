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

/// Submits a new leave request from the HR Leave screen (already open).
Future<void> submitHrLeaveRequest(PatrolIntegrationTester $) async {
  await assertVisibleKey($, QaTestKeys.hrCreateLeaveButton);
  await _ensureKeyTapTarget($, QaTestKeys.hrCreateLeaveButton);
  await $.tester.tap(find.byKey(QaTestKeys.hrCreateLeaveButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await $('Submit').tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.hrLeaveSuccessSnackbar);
}
