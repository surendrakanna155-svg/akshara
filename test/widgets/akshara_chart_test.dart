import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/widgets/finance_collection_trend_chart.dart';
import 'package:akshara_erp/shared/widgets/akshara_analytics_panel.dart';
import 'package:akshara_erp/shared/widgets/akshara_chart.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AksharaChartCard', () {
    testWidgets('renders title, child, and legend', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: AksharaChartCard(
              title: 'Revenue trend',
              legend: AksharaChartLegend(
                items: [
                  AksharaChartLegendItem(color: Colors.blue, label: 'Actual'),
                ],
              ),
              child: SizedBox(height: 120),
            ),
          ),
        ),
      );

      expect(find.text('Revenue trend'), findsOneWidget);
      expect(find.text('Actual'), findsOneWidget);
    });

    testWidgets('shows empty state when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: AksharaChartCard(
              title: 'Empty chart',
              emptyState: AksharaChartEmpty(
                message: 'No chart data available.',
              ),
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(find.text('No data yet'), findsOneWidget);
      expect(find.text('No chart data available.'), findsOneWidget);
    });
  });

  group('FinanceCollectionTrendChart', () {
    testWidgets('renders bars and performance legend for data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: FinanceCollectionTrendChart(
              title: 'Collection trend',
              height: 220,
              points: [
                CollectionTrendPoint(
                  label: 'Jan',
                  amountLakhs: 8.2,
                  targetLakhs: 10,
                ),
                CollectionTrendPoint(
                  label: 'Feb',
                  amountLakhs: 11.5,
                  targetLakhs: 10,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Collection trend'), findsOneWidget);
      expect(find.text('Collected'), findsOneWidget);
      expect(find.textContaining('of target'), findsOneWidget);
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Feb'), findsOneWidget);
    });

    testWidgets('shows chart empty state when points are empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: FinanceCollectionTrendChart(
              title: 'Collection trend',
              points: [],
            ),
          ),
        ),
      );

      expect(find.text('No data yet'), findsOneWidget);
      expect(find.textContaining('Trend data will appear'), findsOneWidget);
    });
  });

  group('AksharaAnalyticsFilterBar', () {
    testWidgets('highlights selected filter chip', (tester) async {
      var selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AksharaAnalyticsFilterBar(
                  filters: const ['This month', 'Last month'],
                  selectedIndex: selected,
                  onSelected: (index) => setState(() => selected = index),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Last month'));
      await tester.pumpAndSettle();

      expect(selected, 1);
    });
  });
}
