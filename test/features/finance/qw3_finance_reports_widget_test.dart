import 'dart:typed_data';

import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/reports/finance_reports_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-035 — Finance reports export: tapping Export PDF invokes the PDF
/// build + preview path and surfaces feedback; Export Excel invokes the CSV
/// share path and surfaces feedback. The export service is faked so the platform
/// `printing` plugin (layoutPdf / sharePdf) is not driven in the test.
///
/// PRA-P1-49 (S4): the screen now exports the report's real trend DATA through
/// the shared XCT-1 GRID primitives (buildGridReportPdf / shareGridCsv), exactly
/// as HR/Attendance do — so the fake overrides those, not the key/value tabular
/// builders it used to (mis)use for 3 metadata rows.
class _FakeReportExportService extends AksharaReportExportService {
  const _FakeReportExportService(this.calls);

  final List<String> calls;

  @override
  Future<Uint8List> buildGridReportPdf({
    required String reportTitle,
    required String moduleLabel,
    required List<String> headers,
    required List<List<String>> rows,
    String? generatedAtLabel,
    int? rightAlignFrom,
  }) async {
    // Record the real data-row count so the test proves it is NOT the old
    // 3-metadata-row stub.
    calls.add('buildGridPdf:$reportTitle:${rows.length}');
    return Uint8List(0);
  }

  @override
  Future<void> previewPdf({
    required String documentName,
    required Uint8List bytes,
  }) async {
    calls.add('previewPdf:$documentName');
  }

  @override
  Future<void> shareGridCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    calls.add('shareGridCsv:$filename:${rows.length}');
  }
}

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(WidgetTester tester, List<String> calls) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        aksharaReportExportServiceProvider
            .overrideWithValue(_FakeReportExportService(calls)),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const FinanceReportsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-035 · Finance reports export', () {
    testWidgets('renders the report catalog + both export actions',
        (tester) async {
      await _pump(tester, []);

      expect(find.text('Report catalog'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.financeReportExportPdfButton),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.financeReportExportExcelButton),
        findsOneWidget,
      );
    });

    testWidgets('Export PDF invokes the PDF build + preview and shows feedback',
        (tester) async {
      final calls = <String>[];
      await _pump(tester, calls);

      final pdfButton = find.byKey(QaTestKeys.financeReportExportPdfButton);
      await tester.ensureVisible(pdfButton);
      await tester.pumpAndSettle();
      await tester.tap(pdfButton);
      await tester.pumpAndSettle();

      // PRA-P1-49 (S4): rides the shared GRID PDF builder and carries the real
      // trend series (6 monthly points), not the old 3-metadata-row stub.
      final gridPdfCall =
          calls.firstWhere((c) => c.startsWith('buildGridPdf:'), orElse: () => '');
      expect(gridPdfCall, isNotEmpty);
      expect(gridPdfCall.endsWith(':6'), isTrue);
      expect(calls.any((c) => c.startsWith('previewPdf:')), isTrue);
      expect(
        find.byKey(QaTestKeys.financeReportExportSuccessSnackbar),
        findsOneWidget,
      );
      expect(find.textContaining('PDF ready (6 rows)'), findsOneWidget);
    });

    testWidgets('Export Excel invokes the CSV build + share and shows feedback',
        (tester) async {
      final calls = <String>[];
      await _pump(tester, calls);

      final excelButton = find.byKey(QaTestKeys.financeReportExportExcelButton);
      await tester.ensureVisible(excelButton);
      await tester.pumpAndSettle();
      await tester.tap(excelButton);
      await tester.pumpAndSettle();

      // PRA-P1-49 (S4): shares the real trend grid CSV (6 rows), not metadata.
      final gridCsvCall = calls.firstWhere(
          (c) => c.startsWith('shareGridCsv:'),
          orElse: () => '');
      expect(gridCsvCall, isNotEmpty);
      expect(gridCsvCall.endsWith(':6'), isTrue);
      expect(
        find.byKey(QaTestKeys.financeReportExportSuccessSnackbar),
        findsOneWidget,
      );
      expect(find.textContaining('Excel CSV ready (6 rows)'), findsOneWidget);
    });
  });
}
