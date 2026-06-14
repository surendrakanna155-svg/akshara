import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import 'patrol_helpers.dart';

Future<void> _scrollToInvoiceSection(PatrolIntegrationTester $) async {
  for (var i = 0; i < 10; i++) {
    if ($.tester.any(find.text('Invoice management'))) {
      await scrollModuleBody($, 'Invoice management', times: 1);
      await assertVisibleText($, 'Invoice management');
      return;
    }
    await scrollModuleBody($, 'Generate student fee account', times: 1);
  }
  await assertVisibleText($, 'Invoice management');
}

Future<void> issueDraftInvoice(
  PatrolIntegrationTester $,
  String invoiceId,
) async {
  await _scrollToInvoiceSection($);
  final issueKey = QaTestKeys.financeIssueInvoiceButton(invoiceId);
  await $(issueKey).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.financeInvoiceIssuedSnackbar);
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
}

Future<void> cancelOpenInvoice(
  PatrolIntegrationTester $,
  String invoiceId,
) async {
  await _scrollToInvoiceSection($);
  final cancelKey = QaTestKeys.financeCancelInvoiceButton(invoiceId);
  await $(cancelKey).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await $(QaTestKeys.financeCancelInvoiceConfirmButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.financeInvoiceCancelledSnackbar);
}

Future<void> cancelCollectionRecord(
  PatrolIntegrationTester $,
  String collectionId,
) async {
  await scrollModuleBody($, 'Payment timeline', times: 3);
  final cancelKey = QaTestKeys.financeCancelCollectionButton(collectionId);
  await $(cancelKey).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  await $(QaTestKeys.financeCancelCollectionConfirmButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.financeCollectionCancelledSnackbar);
}
