import 'package:akshara_erp/features/parent/fees/fee_breakdown_card.dart';
import 'package:akshara_erp/features/parent/fees/fee_summary_hero.dart';
import 'package:akshara_erp/features/parent/fees/fees_provider.dart';
import 'package:akshara_erp/features/parent/fees/installment_timeline.dart';
import 'package:akshara_erp/features/parent/fees/parent_fees_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// RC honest-state certification for PA-03 (parent fees).
///
/// `ParentMapper.toFees` defaults annualAmount / paidAmount / progressPercent
/// to 0 because the transport model is non-nullable, so before the school has
/// published a fee structure the hero read "Paid: ₹0 · Annual: ₹0" and the
/// success-toned ring read "0% — of your annual fees paid so far". A collection
/// percentage against a ZERO denominator is undefined, not 0%. These tests pin
/// the undefined case, and pin that a genuinely published structure is still
/// rendered with its exact money values (no arithmetic/formatting change).
Future<void> _pumpWidget(WidgetTester tester, Widget child) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ParentFeesData _unpublished() => const ParentFeesData(
      pendingAmount: 0,
      isOverdue: false,
      dueLabel: '',
      paidAmount: 0,
      annualAmount: 0,
      progressPercent: 0,
      installments: [],
      breakdown: [],
      paymentHistory: [],
    );

void main() {
  group('PA-03 · FeeSummaryHero — honest state', () {
    testWidgets(
        'no published fee structure → no "Paid: ₹0 · Annual: ₹0" success framing',
        (tester) async {
      await _pumpWidget(
        tester,
        const FeeSummaryHero(
          pendingAmount: 0,
          isOverdue: false,
          dueLabel: '',
          paidAmount: 0,
          annualAmount: 0,
        ),
      );

      expect(find.text('Paid: ₹0'), findsNothing);
      expect(find.text('Annual: ₹0'), findsNothing);
      expect(find.text('₹0'), findsNothing);
      expect(find.byType(AksharaSectionEmpty), findsOneWidget);
      expect(
        find.text('No fee structure published for this student yet.'),
        findsOneWidget,
      );
    });

    testWidgets('a published fee structure still shows its exact money values',
        (tester) async {
      await _pumpWidget(
        tester,
        const FeeSummaryHero(
          pendingAmount: 4200,
          isOverdue: true,
          dueLabel: 'Due 12 Jun 2026 · Term 2',
          paidAmount: 18800,
          annualAmount: 23000,
        ),
      );

      expect(find.text('₹4,200'), findsOneWidget);
      expect(find.text('Paid: ₹18,800'), findsOneWidget);
      expect(find.text('Annual: ₹23,000'), findsOneWidget);
      expect(find.byType(AksharaSectionEmpty), findsNothing);
    });
  });

  group('PA-03 · FeeCollectionProgress — honest state', () {
    testWidgets('a percentage against a zero denominator is not shown as 0%',
        (tester) async {
      await _pumpWidget(
        tester,
        const FeeCollectionProgress(percent: 0, annualAmount: 0),
      );

      expect(find.text('0%'), findsNothing);
      expect(find.text('of your annual fees paid so far'), findsNothing);
      expect(find.byType(AksharaSectionEmpty), findsOneWidget);
      expect(
        find.textContaining('Collection progress appears once a fee structure'),
        findsOneWidget,
      );
    });

    testWidgets('a real denominator still renders the measured ring',
        (tester) async {
      await _pumpWidget(
        tester,
        const FeeCollectionProgress(percent: 82, annualAmount: 23000),
      );

      expect(find.text('82%'), findsOneWidget);
      expect(find.text('of your annual fees paid so far'), findsOneWidget);
    });
  });

  group('PA-03 · section headings never sit over dead space', () {
    testWidgets('empty installments render an honest empty state',
        (tester) async {
      await _pumpWidget(
        tester,
        const InstallmentTimeline(installments: []),
      );

      expect(find.text('Installments'), findsOneWidget);
      expect(find.byType(AksharaSectionEmpty), findsOneWidget);
      expect(
        find.text('No installment schedule published yet.'),
        findsOneWidget,
      );
    });

    testWidgets('empty fee breakdown renders an honest empty state',
        (tester) async {
      await _pumpWidget(
        tester,
        const FeeBreakdownCard(categories: []),
      );

      expect(find.text('Fee breakdown'), findsOneWidget);
      expect(find.byType(AksharaSectionEmpty), findsOneWidget);
      expect(find.text('No fee breakdown published yet.'), findsOneWidget);
    });
  });

  group('PA-03 · ParentFeesScreen — no published fee structure', () {
    testWidgets('a parent with no published fee structure sees no "0% paid"',
        (tester) async {
      useMobileViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            parentFeesProvider.overrideWithValue(_unpublished()),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ParentFeesScreen(),
          ),
        ),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(find.text('0%'), findsNothing);
      expect(find.text('Paid: ₹0'), findsNothing);
      expect(find.text('Annual: ₹0'), findsNothing);
      expect(find.text('of your annual fees paid so far'), findsNothing);

      // Every section states honestly that nothing is published yet.
      expect(find.byType(AksharaSectionEmpty), findsNWidgets(4));
    });
  });
}
