import 'package:akshara_erp/features/parent/fees/fee_breakdown_card.dart';
import 'package:akshara_erp/features/parent/fees/fee_summary_hero.dart';
import 'package:akshara_erp/features/parent/fees/fees_provider.dart';
import 'package:akshara_erp/features/parent/fees/installment_timeline.dart';
import 'package:akshara_erp/features/parent/fees/payment_history_card.dart';
import 'package:akshara_erp/shared/widgets/akshara_status_chip.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// QW3 · QA-F-007 (fee breakdown card), QA-F-008 (fee summary hero),
/// QA-F-009 (installment timeline), QA-F-010 (payment history card) and
/// QA-F-011 (PaymentHistorySheet bottom sheet). These parent fee widgets were
/// never pumped — covered here with realistic demo models from the PA-03 spec.

/// Pumps a single fee widget inside a scrollable NIKSHA-themed surface.
Future<void> _pump(WidgetTester tester, Widget child) async {
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

const _categories = <FeeBreakdownCategory>[
  FeeBreakdownCategory(
    id: 'tuition',
    title: 'Tuition',
    initiallyExpanded: true,
    lines: [
      FeeBreakdownLine(label: 'Tuition fee', amount: 18000),
      FeeBreakdownLine(label: 'Lab fee', amount: 2000),
    ],
  ),
  FeeBreakdownCategory(
    id: 'transport',
    title: 'Transport',
    lines: [
      FeeBreakdownLine(label: 'Bus route A', amount: 1200),
    ],
  ),
];

const _installments = <FeeInstallment>[
  FeeInstallment(
    id: 'term_1',
    title: 'Term 1',
    amount: 8000,
    status: FeeInstallmentStatus.paid,
    meta: 'Paid 15 Apr',
    hasReceipt: true,
  ),
  FeeInstallment(
    id: 'term_2',
    title: 'Term 2',
    amount: 4200,
    status: FeeInstallmentStatus.due,
    meta: 'Due 12 Jun',
  ),
  FeeInstallment(
    id: 'term_3',
    title: 'Term 3',
    amount: 5400,
    status: FeeInstallmentStatus.upcoming,
    meta: 'Due Aug 2026',
    isLast: true,
  ),
];

const _history = <PaymentHistoryItem>[
  PaymentHistoryItem(
    id: 'ph_1',
    title: 'Term 1 — Full payment',
    dateLabel: '15 Apr 2026',
    amount: 8000,
    statusLabel: 'Paid',
    isSuccess: true,
  ),
  PaymentHistoryItem(
    id: 'ph_2',
    title: 'Admission fee',
    dateLabel: '2 Mar 2026',
    amount: 5000,
    statusLabel: 'Paid',
    isSuccess: true,
  ),
];

void main() {
  group('QA-F-007 · FeeBreakdownCard', () {
    testWidgets('renders each category, its lines and the category total',
        (tester) async {
      await _pump(tester, const FeeBreakdownCard(categories: _categories));

      expect(find.text('Fee breakdown'), findsOneWidget);
      expect(find.text('Tuition'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      // Tuition is expanded by default index 0 → its lines + total render.
      expect(find.text('Tuition fee'), findsOneWidget);
      expect(find.text('Lab fee'), findsOneWidget);
      // Category header total = 18000 + 2000.
      expect(find.text('₹20,000'), findsOneWidget);
    });

    testWidgets('expands a collapsed category on tap', (tester) async {
      await _pump(tester, const FeeBreakdownCard(categories: _categories));

      // Transport lines are hidden until tapped.
      expect(find.text('Bus route A'), findsNothing);
      await tester.tap(find.text('Transport'));
      await tester.pumpAndSettle();
      expect(find.text('Bus route A'), findsOneWidget);
    });
  });

  group('QA-F-008 · FeeSummaryHero', () {
    testWidgets('renders pending, paid and annual figures with overdue chip',
        (tester) async {
      await _pump(
        tester,
        const FeeSummaryHero(
          pendingAmount: 4200,
          isOverdue: true,
          dueLabel: 'Due 12 Jun 2026 · Term 2',
          paidAmount: 18800,
          annualAmount: 23000,
        ),
      );

      expect(find.text('Total Pending'), findsOneWidget);
      expect(find.text('₹4,200'), findsOneWidget);
      expect(find.text('Due 12 Jun 2026 · Term 2'), findsOneWidget);
      expect(find.text('Paid: ₹18,800'), findsOneWidget);
      expect(find.text('Annual: ₹23,000'), findsOneWidget);
      // Overdue status chip rendered.
      expect(find.byType(AksharaStatusChip), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('hides the overdue chip when not overdue', (tester) async {
      await _pump(
        tester,
        const FeeSummaryHero(
          pendingAmount: 0,
          isOverdue: false,
          dueLabel: 'All installments paid',
          paidAmount: 23000,
          annualAmount: 23000,
        ),
      );

      expect(find.text('Overdue'), findsNothing);
      expect(find.text('All installments paid'), findsOneWidget);
    });
  });

  group('QA-F-009 · InstallmentTimeline', () {
    testWidgets('renders paid, due and upcoming status rows', (tester) async {
      await _pump(
        tester,
        const InstallmentTimeline(installments: _installments),
      );

      expect(find.text('Installments'), findsOneWidget);
      expect(find.text('Term 1'), findsOneWidget);
      expect(find.text('Term 2'), findsOneWidget);
      expect(find.text('Term 3'), findsOneWidget);
      // One chip per status appears.
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
    });

    testWidgets('fires the pay callback only for the due installment',
        (tester) async {
      FeeInstallment? paid;
      await _pump(
        tester,
        InstallmentTimeline(
          installments: _installments,
          onPayInstallment: (i) => paid = i,
        ),
      );

      // Only the due (Term 2) row exposes a Pay now action.
      expect(find.text('Pay now'), findsOneWidget);
      await tester.tap(find.text('Pay now'));
      await tester.pump();
      expect(paid?.id, 'term_2');
    });
  });

  group('QA-F-010 · PaymentHistoryCard', () {
    testWidgets('renders a past payment row', (tester) async {
      await _pump(
        tester,
        PaymentHistoryCard(item: _history[0]),
      );

      expect(find.text('Term 1 — Full payment'), findsOneWidget);
      expect(find.text('15 Apr 2026'), findsOneWidget);
      expect(find.text('₹8,000'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
    });

    testWidgets('renders a failed payment with the error treatment',
        (tester) async {
      await _pump(
        tester,
        const PaymentHistoryCard(
          item: PaymentHistoryItem(
            id: 'ph_fail',
            title: 'Term 2 — Failed',
            dateLabel: '12 Jun 2026',
            amount: 4200,
            statusLabel: 'Failed',
            isSuccess: false,
          ),
        ),
      );

      expect(find.text('Term 2 — Failed'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('QA-F-011 · PaymentHistorySheet', () {
    testWidgets('opens from a host then dismisses', (tester) async {
      useMobileViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides(),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) =>
                          const PaymentHistorySheet(items: _history),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Sheet closed initially.
      expect(find.byType(PaymentHistorySheet), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Sheet open → header + both rows render.
      expect(find.byType(PaymentHistorySheet), findsOneWidget);
      expect(find.text('Payment history'), findsOneWidget);
      expect(find.text('Term 1 — Full payment'), findsOneWidget);
      expect(find.text('Admission fee'), findsOneWidget);

      // Dismiss by tapping the scrim.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentHistorySheet), findsNothing);
    });
  });
}
