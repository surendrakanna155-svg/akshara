import 'package:akshara_erp/core/config/finance_approval_config.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/refunds/finance_refunds_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-032 — Finance create-refund form + approve flow.
/// - The Create-refund dialog opens, renders the form, and Submit fires the
///   create-refund mutation (observable via the success snackbar).
/// - With principal-approval gating OFF, a pending refund's detail panel exposes
///   the inline Approve action, which fires the approve-refund mutation.
///
/// FINDING (P2): the Create-refund dialog's Submit is unconditional
/// (`onConfirm: () => Navigator.of(context).pop(true)` in
/// finance_workflow_actions.dart:282) and the fields are not inside a Form, so
/// an empty "Fee account ID" / "Refund amount" / "Reason" does NOT block submit
/// despite the `required: true` flags (which only add a ` *` to the label). The
/// "submit empty → errors" leg is documented, not asserted as a blocking error.
void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const FinanceRefundsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-032 · Finance refunds', () {
    testWidgets('renders the refund queue + Create refund action',
        (tester) async {
      await _pump(tester);

      expect(find.byKey(QaTestKeys.financeCreateRefundButton), findsOneWidget);
      // Demo refund queue + auto-selected detail panel.
      expect(find.text('Kavya Iyer'), findsWidgets);
      expect(find.text('Refund amount'), findsWidgets);
    });

    testWidgets('Create refund dialog renders its required fields',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(QaTestKeys.financeCreateRefundButton));
      await tester.pumpAndSettle();

      expect(find.text('Create refund request'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Fee account ID *'),
          findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Refund amount *'),
          findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Reason *'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.financeCreateRefundSubmitButton),
        findsOneWidget,
      );
    });

    testWidgets('submitting a valid refund fires the create-refund mutation',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(QaTestKeys.financeCreateRefundButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Fee account ID *'),
        'acct_1024',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Student name'),
        'Test Student',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Refund amount *'),
        '5000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason *'),
        'Overpayment',
      );
      await tester.pump();

      await tester.tap(find.byKey(QaTestKeys.financeCreateRefundSubmitButton));
      await tester.pumpAndSettle();

      // Mutation resolved → success snackbar surfaced.
      expect(
        find.byKey(QaTestKeys.financeRefundCreatedSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('inline Approve fires the approve-refund mutation when gating off',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          // Inline Approve/Reject only render when the Approval Center is NOT
          // the mandated path; with gating ON the panel shows a redirect banner.
          financeApprovalRequiredProvider.overrideWithValue(false),
        ],
      );

      // First pending refund (Kavya Iyer) is auto-selected → Approve is enabled.
      final approve = find.widgetWithText(FilledButton, 'Approve');
      expect(approve, findsOneWidget);

      await tester.tap(approve);
      await tester.pumpAndSettle();

      expect(find.text('Refund approved for Kavya Iyer'), findsOneWidget);
    });
  });
}
