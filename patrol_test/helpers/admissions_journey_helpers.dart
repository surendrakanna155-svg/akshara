import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import 'patrol_helpers.dart';

/// Unique student name for a single admission E2E run.
String uniqueE2eStudentName() => 'Patrol E2E ${DateTime.now().millisecondsSinceEpoch}';

Future<void> enterAksharaFormField(
  PatrolIntegrationTester $,
  Key key,
  String value,
) async {
  final keyed = find.byKey(key);
  expect(keyed, findsOneWidget);

  Finder input = find.descendant(
    of: keyed,
    matching: find.byType(TextFormField),
  );
  if (!$.tester.any(input)) {
    input = find.descendant(
      of: keyed,
      matching: find.byType(TextField),
    );
  }
  if (!$.tester.any(input)) {
    input = keyed;
  }

  await $.tester.tap(input);
  await $.pump(const Duration(milliseconds: 200));
  await $.tester.enterText(input, value);
  await $.pump(const Duration(milliseconds: 300));
}

Future<void> createLeadViaDialog(
  PatrolIntegrationTester $, {
  required String parentName,
  required String studentName,
  String classLabel = '5',
  required String phone,
}) async {
  await $(QaTestKeys.admissionsCreateLeadButton).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await enterAksharaFormField($, QaTestKeys.admissionsLeadParentNameField, parentName);
  await enterAksharaFormField($, QaTestKeys.admissionsLeadStudentNameField, studentName);
  await enterAksharaFormField($, QaTestKeys.admissionsLeadClassField, classLabel);
  await enterAksharaFormField($, QaTestKeys.admissionsLeadPhoneField, phone);
  await $(QaTestKeys.admissionsLeadDialogCreateButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.admissionsLeadCreatedSnackbar);
}

Future<void> createAndSubmitApplication(PatrolIntegrationTester $) async {
  await $(QaTestKeys.admissionsCreateApplicationButton).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await scrollTap($, 'View');
  await assertVisibleKey($, QaTestKeys.admissionsApplicationSubmittedSnackbar);
}

Future<void> completeEnrollmentWizard(
  PatrolIntegrationTester $, {
  String? studentName,
}) async {
  if (studentName != null) {
    await assertVisibleText($, 'Student profile');
    await enterAksharaFormField($, QaTestKeys.enrollmentStudentNameField, studentName);
  } else {
    await assertVisibleText($, 'Student profile');
  }
  await scrollModuleBody($, 'Student profile');
  await tapEnrollmentContinue($);
  await assertVisibleText($, 'Parent / guardian');
  await scrollModuleBody($, 'Parent / guardian');
  await tapEnrollmentContinue($);
  await assertVisibleText($, 'Academic information');
  await scrollModuleBody($, 'Academic information');
  await tapEnrollmentContinue($);
  await assertVisibleText($, 'Review & submit');
  await scrollModuleBody($, 'Review & submit');
  await $(QaTestKeys.enrollmentSubmitButton).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
  await assertVisibleKey($, QaTestKeys.admissionsEnrollmentSubmittedSnackbar);
}

Future<void> _scrollUntilKeyHitTestable(
  PatrolIntegrationTester $,
  Key key, {
  int maxAttempts = 10,
  List<String> scrollAnchors = const [
    'Status workflow',
    'Approval history',
  ],
}) async {
  final finder = find.byKey(key);
  for (var i = 0; i < maxAttempts; i++) {
    if ($.tester.any(finder)) {
      try {
        await $.tester.ensureVisible(finder);
        await $.pump(const Duration(milliseconds: 300));
        return;
      } catch (_) {
        // Keep scrolling — action buttons may sit below stacked cards on mobile.
      }
    }
    final anchor = scrollAnchors[i % scrollAnchors.length];
    await scrollModuleBody($, anchor, times: 1);
  }
}

Future<void> approveEnrollmentForStudent(
  PatrolIntegrationTester $,
  String studentName,
) async {
  final rowKey = QaTestKeys.admissionsApprovalQueueRow(studentName);
  await $(rowKey).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(rowKey).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await _scrollUntilKeyHitTestable($, QaTestKeys.admissionsApproveButton);
  await $(QaTestKeys.admissionsApproveButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.admissionsApprovedSnackbar);
}

Future<void> convertEnrollmentForStudent(
  PatrolIntegrationTester $,
  String studentName,
) async {
  await assertVisibleText($, studentName);
  await $(studentName).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await _scrollUntilKeyHitTestable(
    $,
    QaTestKeys.sisConvertEnrollmentButton,
    scrollAnchors: const [
      'Convert to SIS student',
      'Admissions conversion',
    ],
  );
  await $(QaTestKeys.sisConvertEnrollmentButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
  await assertVisibleKey($, QaTestKeys.sisConversionSuccessSnackbar);
}

Future<void> verifyStudentInRegistry(
  PatrolIntegrationTester $,
  String studentName,
) async {
  await enterAksharaFormField($, QaTestKeys.sisRegistrySearchField, studentName);
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.sisRegistryStudentRow(studentName));
  await assertVisibleText($, studentName);
}

Future<void> verifyStudentInFeeHandoffQueue(
  PatrolIntegrationTester $,
  String studentName,
) async {
  await assertVisibleText($, 'Admissions handoff queue');
  final rowKey = QaTestKeys.financeHandoffQueueRow(studentName);
  await $(rowKey).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(rowKey).scrollTo();
  await assertVisibleText($, studentName);
}
