import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/discounts/finance_discounts_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-033 — Finance discount-rule dialog: open the Add-rule dialog from
/// the discounts screen, confirm the empty-name guard blocks submit, then fill
/// and Save → the create-discount-rule mutation fires (success snackbar).
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
        home: const FinanceDiscountsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-033 · Finance discount-rule dialog', () {
    testWidgets('renders the discounts dashboard + Add rule action',
        (tester) async {
      await _pump(tester);

      expect(find.text('Discount rules'), findsOneWidget);
      expect(find.byKey(QaTestKeys.financeDiscountRuleAddButton), findsOneWidget);
      // Demo rule renders in the table.
      expect(find.text('Early bird payment'), findsWidgets);
    });

    testWidgets('Add-rule dialog renders and the empty-name guard blocks save',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(QaTestKeys.financeDiscountRuleAddButton));
      await tester.pumpAndSettle();

      expect(find.text('Add discount rule'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.financeDiscountRuleCreateSubmitButton),
        findsOneWidget,
      );

      // Submit with an empty rule name → the dialog's guard keeps it open.
      await tester
          .tap(find.byKey(QaTestKeys.financeDiscountRuleCreateSubmitButton));
      await tester.pumpAndSettle();
      expect(find.text('Add discount rule'), findsOneWidget);
    });

    testWidgets('filling the rule and saving fires the create mutation',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(QaTestKeys.financeDiscountRuleAddButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Rule name *'),
        'Sibling discount',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Applies to'),
        'Second child onwards',
      );
      await tester.pump();

      await tester
          .tap(find.byKey(QaTestKeys.financeDiscountRuleCreateSubmitButton));
      await tester.pumpAndSettle();

      // Mutation resolved → confirmation snackbar; dialog closed.
      expect(
        find.text('Discount rule created (pending approval)'),
        findsOneWidget,
      );
      expect(find.text('Add discount rule'), findsNothing);
    });
  });
}
