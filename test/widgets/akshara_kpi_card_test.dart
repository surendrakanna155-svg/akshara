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

    testWidgets('strip height grows with text scale (no clip at 1.5x)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  child: AksharaKpiCard(
                    value: '94%',
                    subtitle: 'Attendance',
                    accent: KpiAccent.success,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // No overflow exception was thrown during layout/paint.
      expect(tester.takeException(), isNull);
      // The strip card grew past its 88px base to make room for the larger text.
      expect(
        tester.getSize(find.byType(AksharaKpiCard)).height,
        greaterThan(88),
      );
    });

    testWidgets('strip height stays 88 at default text scale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: AksharaKpiCard(
                  value: '94%',
                  subtitle: 'Attendance',
                  accent: KpiAccent.success,
                ),
              ),
            ),
          ),
        ),
      );

      // 88px inner SizedBox + 1px border each side. The point: unchanged at
      // the default scale, so no golden churn.
      expect(tester.getSize(find.byType(AksharaKpiCard)).height, 90);
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
