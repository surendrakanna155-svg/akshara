import 'package:akshara_erp/features/finance/student_accounts/finance_student_accounts_provider.dart';
import 'package:akshara_erp/features/finance/student_accounts/finance_student_accounts_screen.dart';
import 'package:akshara_erp/shared/widgets/akshara_empty_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-030 — Finance student-account search field: typing a query filters
/// the list; a non-matching query surfaces the empty state.
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
        home: const FinanceStudentAccountsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-030 · FinanceStudentAccountsScreen', () {
    testWidgets('renders the search field + the demo account list',
        (tester) async {
      await _pump(tester);

      expect(
        find.widgetWithText(TextField, 'Search student or admission number'),
        findsOneWidget,
      );
      // Demo accounts render and one is selected → summary panel shows.
      expect(find.text('Arjun Patel'), findsWidgets);
      expect(find.text('Assigned fee structure'), findsOneWidget);
    });

    testWidgets('typing a matching query keeps the matching account',
        (tester) async {
      await _pump(tester);

      final field = find.byType(TextField).first;
      await tester.enterText(field, 'Arjun');
      await tester.pumpAndSettle();

      // The matching student stays; the summary panel still resolves.
      expect(find.text('Arjun Patel'), findsWidgets);
      expect(find.byType(AksharaEmptyState), findsNothing);
    });

    testWidgets('typing a non-matching query shows the empty state',
        (tester) async {
      await _pump(tester);

      final field = find.byType(TextField).first;
      await tester.enterText(field, 'zzz-no-such-student-9999');
      await tester.pumpAndSettle();

      // Filtered list is empty → in-body empty state renders.
      expect(find.byType(AksharaEmptyState), findsWidgets);
      expect(
        find.text('No student fee accounts match your search.'),
        findsWidgets,
      );
      expect(find.text('Arjun Patel'), findsNothing);
    });

    testWidgets('shows the empty state when the repository result is empty',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          financeStudentAccountsEmptyProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaEmptyState), findsWidgets);
    });
  });
}
