import 'package:akshara_erp/shared/widgets/akshara_kpi_card.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AksharaKpiCard — Phase 4 premium layout', () {
    testWidgets('filled style renders value, label, and trend chip from detail', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: SizedBox(
              height: 140,
              width: 240,
              child: AksharaKpiCard(
                style: AksharaKpiCardStyle.filled,
                value: '₹1.2Cr',
                subtitle: 'Revenue',
                accent: KpiAccent.success,
                detail: '+9% vs last month',
                icon: Icons.trending_up,
              ),
            ),
          ),
        ),
      );

      expect(find.text('₹1.2Cr'), findsOneWidget);
      expect(find.text('Revenue'), findsOneWidget);
      expect(find.text('+9% vs last month'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('filled style shows caption when detail is not a trend', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: SizedBox(
              height: 140,
              width: 240,
              child: AksharaKpiCard(
                style: AksharaKpiCardStyle.filled,
                value: '47',
                subtitle: 'Fee Defaulters',
                accent: KpiAccent.error,
                detail: 'Collection follow-up',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Collection follow-up'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
    });

    test('AksharaKpiPresentation classifies trend strings', () {
      expect(
        AksharaKpiPresentation.isTrendDetail('+9% vs last month'),
        isTrue,
      );
      expect(
        AksharaKpiPresentation.isTrendDetail('Collection follow-up'),
        isFalse,
      );
      expect(
        AksharaKpiPresentation.inferTrendDirection('+9% vs last month'),
        AksharaKpiTrendDirection.up,
      );
    });
  });
}
