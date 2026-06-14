import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import 'patrol_helpers.dart';

Future<void> _scrollUntilKeyHitTestable(
  PatrolIntegrationTester $,
  Key key, {
  int maxAttempts = 10,
  List<String> scrollAnchors = const [
    'Generate student fee account',
    'Admissions handoff queue',
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
        // Mobile stacked layout — keep scrolling.
      }
    }
    final anchor = scrollAnchors[i % scrollAnchors.length];
    await scrollModuleBody($, anchor, times: 1);
  }
}

Future<void> assignFeePlanForStudent(
  PatrolIntegrationTester $,
  String studentName,
) async {
  final rowKey = QaTestKeys.financeHandoffQueueRow(studentName);
  await $(rowKey).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(rowKey).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await _scrollUntilKeyHitTestable($, QaTestKeys.financeAssignFeePlanButton);
  await $(QaTestKeys.financeAssignFeePlanButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.financeFeeAccountCreatedSnackbar);
}

Future<String> readLastInvoiceId(PatrolIntegrationTester $) async {
  await $(QaTestKeys.financeLastInvoiceIdField).waitUntilVisible(
    timeout: const Duration(seconds: 10),
  );
  final finder = find.byKey(QaTestKeys.financeLastInvoiceIdField);
  final widget = $.tester.widget<Text>(finder);
  expect(widget.data, isNotEmpty);
  return widget.data!;
}

Future<void> completeFinanceAssignCollectJourney(
  PatrolIntegrationTester $,
  String studentName, {
  String collectionAmount = '10000',
}) async {
  await assignFeePlanForStudent($, studentName);
  final invoiceId = await readLastInvoiceId($);
  await tapModuleSubNav($, 'finance', 'Collections');
  await assertVisibleText($, 'Collected today');
  await recordCollectionForInvoice(
    $,
    invoiceId: invoiceId,
    amount: collectionAmount,
  );
  await verifyReceiptInCollectionsList($, 'RCP-');
}

Future<void> enterFinanceFormField(
  PatrolIntegrationTester $,
  Key key,
  String value,
) async {
  final keyed = find.byKey(key);
  expect(keyed, findsOneWidget);
  await $.tester.tap(keyed);
  await $.pump(const Duration(milliseconds: 200));
  await $.tester.enterText(keyed, value);
  await $.pump(const Duration(milliseconds: 300));
}

Future<void> recordCollectionForInvoice(
  PatrolIntegrationTester $, {
  String invoiceId = 'inv_1',
  String amount = '5000',
}) async {
  await $(QaTestKeys.financeRecordCollectionButton).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await enterFinanceFormField($, QaTestKeys.financeCollectionInvoiceField, invoiceId);
  await enterFinanceFormField($, QaTestKeys.financeCollectionAmountField, amount);
  await $(QaTestKeys.financeCollectionSubmitButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.financeCollectionSuccessSnackbar);
}

Future<void> verifyReceiptInCollectionsList(
  PatrolIntegrationTester $,
  String receiptQuery,
) async {
  await enterFinanceFormField($, QaTestKeys.financeReceiptSearchField, receiptQuery);
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleText($, receiptQuery);
}
