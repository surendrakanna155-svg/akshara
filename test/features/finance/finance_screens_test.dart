import 'package:akshara_erp/features/finance/collections/finance_collections_provider.dart';
import 'package:akshara_erp/features/finance/collections/finance_collections_screen.dart';
import 'package:akshara_erp/features/finance/dashboard/finance_dashboard_provider.dart';
import 'package:akshara_erp/features/finance/dashboard/finance_dashboard_screen.dart';
import 'package:akshara_erp/features/finance/fee_assignment/finance_fee_assignment_screen.dart';
import 'package:akshara_erp/features/finance/fee_structures/finance_fee_structures_provider.dart';
import 'package:akshara_erp/features/finance/fee_structures/finance_fee_structures_screen.dart';
import 'package:akshara_erp/features/finance/student_accounts/finance_student_accounts_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> pumpFinanceScreen(WidgetTester tester, Widget screen) async {
  useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Finance module screens', () {
    testWidgets('FinanceDashboardScreen renders KPIs and chart', (
      tester,
    ) async {
      await pumpFinanceScreen(tester, const FinanceDashboardScreen());

      expect(find.text('Fee Collected (MTD)'), findsOneWidget);
      expect(find.text('₹42.0L'), findsOneWidget);
      expect(find.text('Collection trend'), findsOneWidget);
      expect(find.text('Recent payments'), findsOneWidget);
      expect(find.textContaining('Collection rate dropped'), findsOneWidget);
    });

    testWidgets('FinanceDashboardScreen shows loading state', (
      tester,
    ) async {
      useDesktopViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeDashboardLoadingProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const FinanceDashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('FinanceFeeStructuresScreen renders catalog', (tester) async {
      await pumpFinanceScreen(tester, const FinanceFeeStructuresScreen());

      expect(find.text('Fee structure catalog'), findsOneWidget);
      expect(find.text('Standard CBSE'), findsOneWidget);
      expect(find.text('Create structure'), findsOneWidget);
    });

    testWidgets('FinanceFeeStructuresScreen shows empty state', (
      tester,
    ) async {
      useDesktopViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeFeeStructuresEmptyProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const FinanceFeeStructuresScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });

    testWidgets('FinanceStudentAccountsScreen renders account list', (
      tester,
    ) async {
      await pumpFinanceScreen(tester, const FinanceStudentAccountsScreen());

      expect(find.text('Arjun Patel'), findsWidgets);
      expect(find.text('Assigned fee structure'), findsOneWidget);
    });

    testWidgets('FinanceFeeAssignmentScreen renders handoff queue', (
      tester,
    ) async {
      await pumpFinanceScreen(tester, const FinanceFeeAssignmentScreen());

      expect(find.text('Admissions handoff queue'), findsOneWidget);
      expect(find.text('Generate student fee account'), findsOneWidget);
    });

    testWidgets('FinanceCollectionsScreen renders payment list', (
      tester,
    ) async {
      await pumpFinanceScreen(tester, const FinanceCollectionsScreen());

      expect(find.text('Collected today'), findsOneWidget);
      expect(find.text('Payment list'), findsOneWidget);
      expect(find.text('RCP-2026-8841'), findsWidgets);
    });

    testWidgets('FinanceCollectionsScreen shows error state', (tester) async {
      useDesktopViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeCollectionsErrorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const FinanceCollectionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
