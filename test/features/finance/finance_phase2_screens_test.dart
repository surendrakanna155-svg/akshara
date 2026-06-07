import 'package:akshara_erp/features/finance/collection_detail/finance_collection_detail_provider.dart';
import 'package:akshara_erp/features/finance/collection_detail/finance_collection_detail_screen.dart';
import 'package:akshara_erp/features/finance/defaulters/finance_defaulters_provider.dart';
import 'package:akshara_erp/features/finance/defaulters/finance_defaulters_screen.dart';
import 'package:akshara_erp/features/finance/discounts/finance_discounts_provider.dart';
import 'package:akshara_erp/features/finance/discounts/finance_discounts_screen.dart';
import 'package:akshara_erp/features/finance/refunds/finance_refunds_screen.dart';
import 'package:akshara_erp/features/finance/reports/finance_reports_screen.dart';
import 'package:akshara_erp/features/finance/settings/finance_settings_provider.dart';
import 'package:akshara_erp/features/finance/settings/finance_settings_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_helpers.dart';

void useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> pumpFinanceScreen(
  WidgetTester tester,
  Widget screen, {
  Size viewport = const Size(1440, 900),
  List<Override> overrides = const [],
}) async {
  useViewport(tester, viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
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
  group('Finance Phase 2 screens — desktop', () {
    testWidgets('FinanceCollectionDetailScreen renders timeline', (
      tester,
    ) async {
      await pumpFinanceScreen(
        tester,
        const FinanceCollectionDetailScreen(collectionId: 'col_1'),
      );

      expect(find.text('RCP-2026-8841'), findsWidgets);
      expect(find.text('Payment timeline'), findsOneWidget);
      expect(find.text('Installment history'), findsOneWidget);
    });

    testWidgets('FinanceCollectionDetailScreen shows loading state', (
      tester,
    ) async {
      useViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            financeCollectionDetailLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const FinanceCollectionDetailScreen(collectionId: 'col_1'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('FinanceDefaultersScreen renders KPIs and list', (
      tester,
    ) async {
      await pumpFinanceScreen(tester, const FinanceDefaultersScreen());

      expect(find.text('Total overdue'), findsOneWidget);
      expect(find.text('Defaulters list'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsWidgets);
    });

    testWidgets('FinanceDefaultersScreen shows empty state', (tester) async {
      await pumpFinanceScreen(
        tester,
        const FinanceDefaultersScreen(),
        overrides: [
          financeDefaultersEmptyProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });

    testWidgets('FinanceRefundsScreen renders queue and detail', (
      tester,
    ) async {
      await pumpFinanceScreen(tester, const FinanceRefundsScreen());

      expect(find.text('Kavya Iyer'), findsWidgets);
      expect(find.text('Withdrawal — family relocation'), findsOneWidget);
    });

    testWidgets('FinanceDiscountsScreen renders catalog', (tester) async {
      await pumpFinanceScreen(tester, const FinanceDiscountsScreen());

      expect(find.text('Scholarship catalog'), findsOneWidget);
      expect(find.text('Merit Scholarship'), findsAtLeastNWidgets(1));
    });

    testWidgets('FinanceReportsScreen renders catalog and export', (
      tester,
    ) async {
      await pumpFinanceScreen(tester, const FinanceReportsScreen());

      expect(find.text('Report catalog'), findsOneWidget);
      expect(find.text('Collection Report'), findsOneWidget);
    });

    testWidgets('FinanceSettingsScreen renders sections', (tester) async {
      await pumpFinanceScreen(tester, const FinanceSettingsScreen());

      expect(find.text('Finance settings'), findsOneWidget);
      expect(find.text('Academic year setup'), findsOneWidget);
    });
  });

  group('Finance Phase 2 screens — tablet', () {
    testWidgets('FinanceDefaultersScreen renders on tablet', (tester) async {
      await pumpFinanceScreen(
        tester,
        const FinanceDefaultersScreen(),
        viewport: const Size(834, 1194),
      );

      expect(find.text('Aging buckets'), findsOneWidget);
    });

    testWidgets('FinanceRefundsScreen renders on tablet', (tester) async {
      await pumpFinanceScreen(
        tester,
        const FinanceRefundsScreen(),
        viewport: const Size(834, 1194),
      );

      expect(find.text('Withdrawal — family relocation'), findsOneWidget);
    });
  });

  group('Finance Phase 2 screens — mobile', () {
    testWidgets('FinanceDefaultersScreen renders cards on mobile', (
      tester,
    ) async {
      await pumpFinanceScreen(
        tester,
        const FinanceDefaultersScreen(),
        viewport: const Size(390, 844),
      );

      expect(find.text('Defaulters list'), findsOneWidget);
    });

    testWidgets('FinanceDiscountsScreen shows error state', (tester) async {
      await pumpFinanceScreen(
        tester,
        const FinanceDiscountsScreen(),
        viewport: const Size(390, 844),
        overrides: [
          financeDiscountsErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });

    testWidgets('FinanceSettingsScreen shows loading on mobile', (
      tester,
    ) async {
      useViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            financeSettingsLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const FinanceSettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });
  });
}
