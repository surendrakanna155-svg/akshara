// INV-5 — GRN (goods received) register export riding the XCT-1 grid
// primitive on the inventory reports screen.
//
// The export service is faked so the platform `printing` plugin is never
// driven; every grid call captures filename + headers + rows so we can assert
// BOTH that the export path fired and that the GRN → grid mapping carries the
// vendor / PO reference / line summary from the repository row.

import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/inventory/reports/inventory_reports_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

class _GridCall {
  const _GridCall(this.kind, this.filename, this.headers, this.rows);

  final String kind;
  final String filename;
  final List<String> headers;
  final List<List<String>> rows;
}

class _FakeExportService extends AksharaReportExportService {
  const _FakeExportService(this.calls);

  final List<_GridCall> calls;

  @override
  Future<void> shareGridCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    calls.add(_GridCall('csv', filename, headers, rows));
  }

  @override
  Future<void> shareGridPdf({
    required String filename,
    required String reportTitle,
    required String moduleLabel,
    required List<String> headers,
    required List<List<String>> rows,
    String? generatedAtLabel,
    int? rightAlignFrom,
  }) async {
    calls.add(_GridCall('pdf', filename, headers, rows));
  }
}

Future<void> _pump(WidgetTester tester, List<_GridCall> calls) async {
  tester.view.physicalSize = const Size(1440, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        aksharaReportExportServiceProvider
            .overrideWithValue(_FakeExportService(calls)),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const InventoryReportsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final button = find.byKey(key);
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('INV-5 — GRN register export', () {
    testWidgets('reports screen renders GRN CSV + PDF export buttons',
        (tester) async {
      await _pump(tester, []);
      expect(
        find.byKey(const ValueKey('inventoryGrnExportCsvButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('inventoryGrnExportPdfButton')),
        findsOneWidget,
      );
    });

    testWidgets('GRN CSV export fires the grid export with the GRN mapping',
        (tester) async {
      final calls = <_GridCall>[];
      await _pump(tester, calls);
      await _tap(tester, const ValueKey('inventoryGrnExportCsvButton'));

      final call = calls.singleWhere((c) => c.kind == 'csv');
      expect(call.filename, 'grn_register');
      expect(call.headers, [
        'GRN number',
        'PO number',
        'Vendor',
        'Received at',
        'Status',
        'Lines',
      ]);
      // Mock repository seeds exactly one GRN; the row carries the vendor +
      // PO reference + line summary.
      expect(call.rows, hasLength(1));
      final row = call.rows.single;
      expect(row[0], 'GRN-PO-2026-0142-482910');
      expect(row[1], 'PO-2026-0142');
      expect(row[2], 'Akshara Stationery Supplies');
      expect(row[4], 'posted');
      expect(row[5], '2');
      expect(
        find.byKey(QaTestKeys.inventoryReportExportSuccessSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('GRN PDF export fires the grid PDF path + feedback',
        (tester) async {
      final calls = <_GridCall>[];
      await _pump(tester, calls);
      await _tap(tester, const ValueKey('inventoryGrnExportPdfButton'));

      final call = calls.singleWhere((c) => c.kind == 'pdf');
      expect(call.filename, 'grn_register');
      expect(call.rows, hasLength(1));
      expect(
        find.byKey(QaTestKeys.inventoryReportExportSuccessSnackbar),
        findsOneWidget,
      );
    });
  });
}
