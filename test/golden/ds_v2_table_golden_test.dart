@TestOn('mac-os')
library;

import 'package:akshara_erp/shared/widgets/akshara_virtualized_data_table.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/spacing.dart';
import 'package:akshara_erp/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// DS V2 P2-7 — data-table goldens. Pins the premium virtualized table (filled
/// header band + header/cell alignment) in Light + Dark. No feature screen that
/// uses `AksharaVirtualizedDataTable` renders it in a golden (they show empty /
/// loading states), so this is the table's visual safety net.

const _rows = [
  ('Aarav Sharma', 'Class 8-A', 'Paid', '₹12,000'),
  ('Diya Patel', 'Class 8-A', 'Due', '₹4,500'),
  ('Kabir Singh', 'Class 8-B', 'Paid', '₹12,000'),
  ('Ananya Rao', 'Class 8-B', 'Partial', '₹8,250'),
  ('Vivaan Gupta', 'Class 8-C', 'Due', '₹12,000'),
];

class _SampleTable extends StatelessWidget {
  const _SampleTable();

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: AksharaVirtualizedDataTable(
            tableHeight: 320,
            columns: [
              DataColumn(label: Text('Student', style: text.tableHeader)),
              DataColumn(label: Text('Class', style: text.tableHeader)),
              DataColumn(label: Text('Status', style: text.tableHeader)),
              DataColumn(
                numeric: true,
                label: Text('Amount', style: text.tableHeader),
              ),
            ],
            rowCount: _rows.length,
            rowBuilder: (i) {
              final r = _rows[i];
              return DataRow(
                cells: [
                  DataCell(Text(r.$1)),
                  DataCell(Text(r.$2)),
                  DataCell(Text(r.$3)),
                  DataCell(Text(r.$4)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

void main() {
  const viewport = Size(834, 460);

  for (final mode in const [
    (label: 'light', dark: false),
    (label: 'dark', dark: true),
  ]) {
    testWidgets('DS V2 data table · ${mode.label}', (tester) async {
      suppressGoldenOverflowErrors();
      useGoldenViewport(tester, viewport);

      await tester.pumpWidget(
        MaterialApp(
          theme: mode.dark ? AksharaAppTheme.dark() : AksharaAppTheme.light(),
          debugShowCheckedModeBanner: false,
          home: const _SampleTable(),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(_SampleTable),
        matchesGoldenFile(goldenFileName('ds_v2_table_${mode.label}', '834x460')),
      );
    });
  }
}
