import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/parent/fees/fees_provider.dart';
import 'package:akshara_erp/features/parent/fees/parent_fees_screen.dart';
import 'package:akshara_erp/features/parent/payment/parent_payment_provider.dart';
import 'package:akshara_erp/features/parent/payment/parent_payment_screen.dart';
import 'package:akshara_erp/features/parent/payment/payment_models.dart';
import 'package:akshara_erp/features/parent/receipts/parent_receipt_detail_screen.dart';
import 'package:akshara_erp/features/parent/receipts/parent_receipts_provider.dart';
import 'package:akshara_erp/features/parent/receipts/parent_receipts_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW7 · QA-C-001 — Parent app *behaviour* certification (Batch 2).
///
/// This row sits ON TOP of the existing QW1–QW6 Parent widget coverage, which
/// already proves rendering + the 4 async states per screen:
///   • test/features/parent/parent_fees_screen_widget_test.dart   (QA-F-005/006:
///     ParentFeesScreen render + loading/error; PayNowBottomBar tap/disabled)
///   • test/features/parent/parent_fees_flow_screens_test.dart    (ParentPayment
///     processing/failure states; ParentReceipts list/empty; receipt download
///     callback; ParentLeave error)
///   • test/features/parent/parent_more_screens_test.dart         (Notices loading,
///     Events empty, Profile error)
///   • test/features/parent/parent_fees_payment_loop_test.dart    (the money loop
///     at the repository level — pay → paid → dues drop → receipt)
///
/// Rather than re-pump every element (infinite), this cert asserts, over a few
/// representative Parent screens, that a key clickable element FIRES ITS EXPECTED
/// ACTION (Pay Now → payment navigation callback; receipt Download → callback)
/// and that the canonical loading / error / empty / success states render.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  if (settle) {
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  } else {
    // The loading-state spinner animates forever; pumpAndSettle would hang.
    await tester.pump();
  }
}

void main() {
  group('QA-C-001 · Parent app — clickable behaviour', () {
    testWidgets('Pay Now fires the payment-navigation callback with the term id',
        (tester) async {
      // The #1 Parent journey: tapping Pay Now must hand the installment id to
      // the navigation callback that opens the PA-10 payment flow.
      String? navigatedInstallment;
      var fired = 0;
      await _pump(
        tester,
        ParentFeesScreen(
          onPayNow: ({String? installmentId}) {
            fired++;
            navigatedInstallment = installmentId;
          },
        ),
        overrides: [
          parentFeesProvider.overrideWithValue(ParentFeesData.mock()),
        ],
      );

      // The sticky Pay Now CTA is present because there are pending dues.
      expect(find.text('Pay Now'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Pay Now'));
      await tester.pump();

      expect(fired, 1);
      expect(navigatedInstallment, 'term_2');
    });

    testWidgets('receipt Download fires its callback with the receipt id',
        (tester) async {
      // Citing parent_fees_flow_screens_test.dart's download cert and re-asserting
      // it as a Parent-app behaviour row: a representative non-nav action wires up.
      var downloadedReceiptId = '';
      await _pump(
        tester,
        ParentReceiptDetailScreen(
          receiptId: 'rcpt_term_1',
          onDownload: (receipt) => downloadedReceiptId = receipt.id,
        ),
      );

      await tester.tap(find.byKey(QaTestKeys.parentReceiptDownloadButton));
      await tester.pumpAndSettle();

      expect(downloadedReceiptId, 'rcpt_term_1');
    });
  });

  group('QA-C-001 · Parent app — canonical 4 states render', () {
    testWidgets('SUCCESS — fees screen settles into its data path',
        (tester) async {
      await _pump(
        tester,
        const ParentFeesScreen(),
        overrides: [
          parentFeesProvider.overrideWithValue(ParentFeesData.mock()),
        ],
      );

      expect(find.text('Fees'), findsOneWidget);
      expect(find.byType(AksharaLoadingState), findsNothing);
      expect(find.byType(AksharaErrorState), findsNothing);
    });

    testWidgets('LOADING — fees screen shows AksharaLoadingState',
        (tester) async {
      await _pump(
        tester,
        const ParentFeesScreen(),
        overrides: [parentFeesLoadingProvider.overrideWith((ref) => true)],
        settle: false,
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('ERROR — fees screen shows AksharaErrorState',
        (tester) async {
      await _pump(
        tester,
        const ParentFeesScreen(),
        overrides: [parentFeesErrorProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });

    testWidgets('EMPTY — receipts screen shows AksharaEmptyState',
        (tester) async {
      await _pump(
        tester,
        const ParentReceiptsScreen(),
        overrides: [parentReceiptsEmptyProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });

    testWidgets('payment screen PROCESSING shows the loading affordance',
        (tester) async {
      await _pump(
        tester,
        const ParentPaymentScreen(installmentId: 'term_2'),
        overrides: [
          parentPaymentPhaseProvider
              .overrideWith((ref) => PaymentFlowPhase.processing),
        ],
        settle: false,
      );
      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('payment screen FAILURE shows the recoverable error affordance',
        (tester) async {
      await _pump(
        tester,
        const ParentPaymentScreen(installmentId: 'term_2'),
        overrides: [
          parentPaymentPhaseProvider
              .overrideWith((ref) => PaymentFlowPhase.failure),
        ],
      );
      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
