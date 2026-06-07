import 'package:akshara_erp/features/parent/leave/parent_leave_provider.dart';
import 'package:akshara_erp/features/parent/leave/parent_leave_screen.dart';
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

Future<void> pumpParentScreen(WidgetTester tester, Widget screen) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('Parent fees flow screens', () {
    testWidgets('ParentPaymentScreen renders payment summary', (tester) async {
      await pumpParentScreen(
        tester,
        const ParentPaymentScreen(installmentId: 'term_2'),
      );

      expect(find.text('Pay Fee'), findsOneWidget);
      expect(find.text('Payment method'), findsOneWidget);
      expect(find.text('Pay now'), findsOneWidget);
    });

    testWidgets('ParentPaymentScreen shows failure state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            parentPaymentPhaseProvider.overrideWith(
              (ref) => PaymentFlowPhase.failure,
            ),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ParentPaymentScreen(installmentId: 'term_2'),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });

    testWidgets('ParentPaymentScreen shows processing state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            parentPaymentPhaseProvider.overrideWith(
              (ref) => PaymentFlowPhase.processing,
            ),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ParentPaymentScreen(installmentId: 'term_2'),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('ParentReceiptsScreen renders receipts list', (tester) async {
      await pumpParentScreen(tester, const ParentReceiptsScreen());

      expect(find.text('Receipts'), findsOneWidget);
      expect(find.text('Term 1 — Full payment'), findsOneWidget);
    });

    testWidgets('ParentReceiptsScreen shows empty state when forced', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            parentReceiptsEmptyProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ParentReceiptsScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });

    testWidgets('ParentReceiptDetailScreen renders receipt detail', (
      tester,
    ) async {
      await pumpParentScreen(
        tester,
        const ParentReceiptDetailScreen(receiptId: 'rcpt_term_1'),
      );

      expect(find.text('Receipt'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('ParentLeaveScreen renders leave history', (tester) async {
      await pumpParentScreen(tester, const ParentLeaveScreen());

      expect(find.text('Leave Requests'), findsOneWidget);
      expect(find.text('History'), findsWidgets);
      expect(find.text('Apply leave'), findsOneWidget);
    });

    testWidgets('ParentLeaveScreen shows error state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            parentLeaveErrorProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ParentLeaveScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
