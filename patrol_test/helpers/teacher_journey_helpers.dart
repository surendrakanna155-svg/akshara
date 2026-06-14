import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import 'patrol_helpers.dart';

Future<void> submitClassAttendance(PatrolIntegrationTester $) async {
  await assertVisibleText($, 'Ravi Kumar');
  await scrollTap($, 'All present');
  await $(QaTestKeys.teacherAttendanceSubmitButton)
      .waitUntilVisible(timeout: const Duration(seconds: 15));
  await scrollTap($, 'Submit');
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.teacherAttendanceSubmittedBanner);
}

Future<void> assertSubmitDisabled(PatrolIntegrationTester $) async {
  final finder = find.byKey(QaTestKeys.teacherAttendanceSubmitButton);
  expect(finder, findsOneWidget);
  final button = $.tester.widget<FilledButton>(finder);
  expect(button.onPressed, isNull);
}

Future<void> verifyAttendanceSubmissionPersists(PatrolIntegrationTester $) async {
  await tapBottomNav($, 'Teach');
  await assertVisibleText($, 'Homework Review');
  await tapBottomNav($, 'Classes');
  await assertVisibleText($, 'Mark Attendance');
  await assertVisibleKey($, QaTestKeys.teacherAttendanceSubmittedBanner);
  await assertSubmitDisabled($);
}
