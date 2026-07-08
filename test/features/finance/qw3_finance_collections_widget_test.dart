import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/collections/finance_collections_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-031 — Finance collect-payment dialog: open from the collections
/// screen, enter amount/method, and confirm → the create-collection mutation
/// fires (observable via the success snackbar).
///
/// FINDING (P2): the Record-collection dialog's confirm button is unconditional
/// (`onConfirm: () => Navigator.of(context).pop(true)` in
/// finance_workflow_actions.dart:778) — there is no Form/validator, so an empty
/// amount does NOT block submission. The "submit empty → validation" leg is
/// therefore documented, not asserted as a blocking error.
void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(WidgetTester tester) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const FinanceCollectionsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

Future<void> _openCollectDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(QaTestKeys.financeRecordCollectionButton));
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-031 · Finance collect-payment dialog', () {
    testWidgets('the Record collection action is visible to finance staff',
        (tester) async {
      await _pump(tester);

      expect(
        find.byKey(QaTestKeys.financeRecordCollectionButton),
        findsOneWidget,
      );
    });

    testWidgets('opening the dialog renders amount + submit controls',
        (tester) async {
      await _pump(tester);
      await _openCollectDialog(tester);

      expect(find.text('Record collection'), findsWidgets);
      expect(
        find.byKey(QaTestKeys.financeCollectionInvoiceField),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.financeCollectionAmountField),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.financeCollectionSubmitButton),
        findsOneWidget,
      );
      // Payment-method selector present.
      expect(find.widgetWithText(DropdownMenu<String>, 'Payment method'),
          findsOneWidget);
    });

    testWidgets('confirming with an amount fires the create-collection mutation',
        (tester) async {
      await _pump(tester);
      await _openCollectDialog(tester);

      await tester.enterText(
        find.byKey(QaTestKeys.financeCollectionAmountField),
        '7500',
      );
      await tester.pump();

      await tester.tap(find.byKey(QaTestKeys.financeCollectionSubmitButton));
      await tester.pumpAndSettle();

      // The mutation resolved → the success CEREMONY (P2-UX-2 §2.4) surfaced and
      // the collect dialog closed.
      expect(
        find.byKey(QaTestKeys.financeCollectionSuccessCeremony),
        findsOneWidget,
      );
      expect(find.text('Payment received'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.financeCollectionAmountField),
        findsNothing,
      );
    });
  });
}
