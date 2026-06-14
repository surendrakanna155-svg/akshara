import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import 'patrol_helpers.dart';

Future<void> issueLibraryBook(PatrolIntegrationTester $) async {
  await assertVisibleKey($, QaTestKeys.libraryIssueScanButton);
  await $.tester.ensureVisible(find.byKey(QaTestKeys.libraryIssueScanButton));
  await $.tester.tap(find.byKey(QaTestKeys.libraryIssueScanButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await assertVisibleKey($, QaTestKeys.libraryIssueDialogSubmitButton);
  await $.tester.tap(find.byKey(QaTestKeys.libraryIssueDialogSubmitButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.libraryIssueSuccessSnackbar);
}

Future<void> returnLibraryBook(PatrolIntegrationTester $, String issueId) async {
  final returnKey = QaTestKeys.libraryReturnBookButton(issueId);
  await assertVisibleKey($, returnKey);
  await $.tester.ensureVisible(find.byKey(returnKey));
  await $.tester.tap(find.byKey(returnKey));
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await assertVisibleKey($, QaTestKeys.libraryReturnDialogSubmitButton);
  await $.tester.tap(find.byKey(QaTestKeys.libraryReturnDialogSubmitButton));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.libraryReturnSuccessSnackbar);
}
