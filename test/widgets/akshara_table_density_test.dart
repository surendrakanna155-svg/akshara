import 'package:akshara_erp/shared/widgets/akshara_virtualized_data_table.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P2-UX-2 C2 — row density as a table property (clerk compact vs calm standard).
void main() {
  Future<double> firstRowHeight(
    WidgetTester tester,
    AksharaTableDensity density,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: AksharaVirtualizedDataTable(
            density: density,
            tableHeight: 300,
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Class')),
            ],
            rowCount: 3,
            rowBuilder: (i) => DataRow(
              cells: [DataCell(Text('Student $i')), const DataCell(Text('5A'))],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.getSize(find.byType(InkWell).first).height;
  }

  testWidgets('compact density renders shorter rows than standard',
      (tester) async {
    final standard = await firstRowHeight(tester, AksharaTableDensity.standard);
    final compact = await firstRowHeight(tester, AksharaTableDensity.compact);

    expect(compact, lessThan(standard),
        reason: 'compact (40px) packs rows tighter than standard (52px)');
    expect(compact, lessThanOrEqualTo(40.0));
  });

  testWidgets('default density is standard', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: AksharaVirtualizedDataTable(
            columns: const [DataColumn(label: Text('Name'))],
            rowCount: 1,
            rowBuilder: (i) => const DataRow(cells: [DataCell(Text('A'))]),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(InkWell).first).height,
        greaterThanOrEqualTo(52.0));
  });
}
