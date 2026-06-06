import 'package:akshara_erp/shared/widgets/akshara_kpi_card.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AksharaKpiCard renders filled style value and label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Scaffold(
          body: AksharaKpiCard(
            style: AksharaKpiCardStyle.filled,
            value: '5/6',
            subtitle: 'Classes marked',
            accent: KpiAccent.primary,
          ),
        ),
      ),
    );

    expect(find.text('5/6'), findsOneWidget);
    expect(find.text('Classes marked'), findsOneWidget);
  });
}
