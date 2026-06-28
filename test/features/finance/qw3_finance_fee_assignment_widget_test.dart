import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/fee_assignment/finance_fee_assignment_provider.dart';
import 'package:akshara_erp/features/finance/fee_assignment/finance_fee_assignment_screen.dart';
import 'package:akshara_erp/features/finance/integration/finance_admissions_handoff_provider.dart';
import 'package:akshara_erp/shared/widgets/akshara_empty_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_loading_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-034 — Finance fee-assignment screen (provider ~31% lcov): render
/// the admissions handoff queue + assignment panel, drive the
/// generate-fee-account flow, and force the empty / error / loading branches.
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
  bool settle = true,
}) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const FinanceFeeAssignmentScreen(),
      ),
    ),
  );
  if (settle) {
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  group('QA-F-034 · FinanceFeeAssignmentScreen', () {
    testWidgets('renders the handoff queue + assignment panel', (tester) async {
      await _pump(tester);

      expect(find.text('Admissions handoff queue'), findsOneWidget);
      expect(
        find.text('Assign fee structure and generate student fee account'),
        findsOneWidget,
      );
      // Assignment panel CTA for the selected handoff.
      expect(find.text('Generate student fee account'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.financeAssignFeePlanButton),
        findsOneWidget,
      );
    });

    testWidgets('generating a fee account fires the assign mutation',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(QaTestKeys.financeAssignFeePlanButton));
      await tester.pumpAndSettle();

      // Mutation resolved → fee-account-created confirmation snackbar.
      expect(
        find.byKey(QaTestKeys.financeFeeAccountCreatedSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('shows the empty state when no handoffs are pending',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          // Drain the handoff queue → both queue and generated are empty.
          financeHandoffQueueProvider.overrideWithValue(const []),
        ],
      );

      expect(find.byType(AksharaEmptyState), findsWidgets);
      expect(
        find.text('No students awaiting fee assignment.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the error state when installment plans fail',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          financeFeeAssignmentErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });

    testWidgets('shows the loading state when forced', (tester) async {
      await _pump(
        tester,
        overrides: [
          financeFeeAssignmentLoadingProvider.overrideWith((ref) => true),
        ],
        settle: false,
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });
  });
}
