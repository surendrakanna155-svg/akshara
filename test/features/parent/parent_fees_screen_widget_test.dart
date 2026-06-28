import 'package:akshara_erp/features/parent/fees/fee_breakdown_card.dart';
import 'package:akshara_erp/features/parent/fees/fee_summary_hero.dart';
import 'package:akshara_erp/features/parent/fees/fees_provider.dart';
import 'package:akshara_erp/features/parent/fees/parent_fees_screen.dart';
import 'package:akshara_erp/features/parent/fees/pay_now_bottom_bar.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW1 · QA-F-005 (ParentFeesScreen render + loading/error states) and
/// QA-F-006 (PayNowBottomBar tap / disabled-when-zero / amount label).
///
/// Both surfaces were 0% lcov / never pumped before this; the money loop is the
/// #1 QW1 priority so the fees summary + sticky CTA get first-class widget
/// coverage here.
Future<void> _pumpScreen(
  WidgetTester tester, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const ParentFeesScreen(),
      ),
    ),
  );
  if (settle) {
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  } else {
    // The loading state animates forever, so pumpAndSettle would time out.
    await tester.pump();
  }
}

Future<void> _pumpBar(
  WidgetTester tester,
  Widget bar,
) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: bar)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-005 · ParentFeesScreen', () {
    testWidgets('renders the fees summary hero + breakdown', (tester) async {
      await _pumpScreen(
        tester,
        overrides: [parentFeesProvider.overrideWithValue(ParentFeesData.mock())],
      );

      expect(find.text('Fees'), findsOneWidget); // app bar title
      expect(find.byType(FeeSummaryHero), findsOneWidget);
      expect(find.byType(FeeBreakdownCard), findsOneWidget);
    });

    testWidgets('shows the loading state when forced', (tester) async {
      await _pumpScreen(
        tester,
        overrides: [
          parentFeesLoadingProvider.overrideWith((ref) => true),
        ],
        settle: false,
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
      expect(find.byType(FeeSummaryHero), findsNothing);
    });

    testWidgets('shows the error state when forced', (tester) async {
      await _pumpScreen(
        tester,
        overrides: [
          parentFeesErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(find.text('Unable to load fees right now.'), findsOneWidget);
    });
  });

  group('QA-F-006 · PayNowBottomBar', () {
    testWidgets('renders the amount-due label', (tester) async {
      await _pumpBar(
        tester,
        PayNowBottomBar(amountDue: 4200, onPayNow: () {}),
      );

      expect(find.text('Amount due'), findsOneWidget);
      expect(find.text('₹4,200'), findsOneWidget);
      expect(find.text('Pay Now'), findsOneWidget);
    });

    testWidgets('fires onPayNow when due > 0', (tester) async {
      var tapped = 0;
      await _pumpBar(
        tester,
        PayNowBottomBar(amountDue: 4200, onPayNow: () => tapped++),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Pay Now'));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('is disabled when amount due is zero', (tester) async {
      var tapped = 0;
      await _pumpBar(
        tester,
        PayNowBottomBar(amountDue: 0, onPayNow: () => tapped++),
      );

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Pay Now'),
      );
      expect(button.onPressed, isNull); // disabled
      expect(find.text('₹0'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Pay Now'),
          warnIfMissed: false);
      await tester.pump();
      expect(tapped, 0);
    });

    testWidgets('is disabled when enabled=false even with due > 0',
        (tester) async {
      await _pumpBar(
        tester,
        PayNowBottomBar(amountDue: 4200, onPayNow: () {}, enabled: false),
      );

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Pay Now'),
      );
      expect(button.onPressed, isNull);
    });
  });
}
