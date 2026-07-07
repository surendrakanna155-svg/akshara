import 'package:akshara_erp/shared/widgets/akshara_executive_kpi_card.dart';
import 'package:akshara_erp/shared/widgets/akshara_sparkline.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// P2-UX-1 / A6 — the executive KPI card must show the REAL series or nothing;
// it no longer fabricates a decorative hash-series when a live series is absent.

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(theme: AksharaAppTheme.light(), home: Scaffold(body: child)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AksharaExecutiveKpiCard — A6 (no fabricated sparkline)', () {
    testWidgets('renders NO sparkline when no real series is provided',
        (tester) async {
      await _pump(
        tester,
        const AksharaExecutiveKpiCard(label: 'Revenue', value: '₹1.2L'),
      );
      expect(find.byType(AksharaSparkline), findsNothing);
    });

    testWidgets('renders a sparkline when a real series IS provided',
        (tester) async {
      await _pump(
        tester,
        const AksharaExecutiveKpiCard(
          label: 'Revenue',
          value: '₹1.2L',
          sparklinePoints: [0.1, 0.5, 0.9, 0.4],
        ),
      );
      expect(find.byType(AksharaSparkline), findsOneWidget);
    });
  });
}
