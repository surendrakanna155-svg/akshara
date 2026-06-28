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
/// build + share path and surfaces feedback. The export service is faked so the
/// platform `printing` plugin (layoutPdf / sharePdf) is not driven in the test.
class _FakeReportExportService extends AksharaReportExportService {
  const _FakeReportExportService(this.calls);

  final List<String> calls;

  @override
  Future<Uint8List> buildTabularReportPdf({
    required String reportTitle,
    required String moduleLabel,
    required List<MapEntry<String, String>> rows,
    String? generatedAtLabel,
  }) async {
    calls.add('buildPdf:$reportTitle');
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
  String buildTabularReportCsv({
    required String reportTitle,
    required List<MapEntry<String, String>> rows,
  }) {
    calls.add('buildCsv:$reportTitle');
    // Two data rows so the screen's "(N rows)" feedback is deterministic.
    return 'Report,$reportTitle\nField,Value\nA,1\nB,2';
  }

  @override
  Future<void> shareTabularCsv({
    required String filename,
    required String reportTitle,
    required List<MapEntry<String, String>> rows,
  }) async {
    calls.add('shareCsv:$filename');
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

      expect(calls.any((c) => c.startsWith('buildPdf:')), isTrue);
      expect(calls.any((c) => c.startsWith('previewPdf:')), isTrue);
      expect(
        find.byKey(QaTestKeys.financeReportExportSuccessSnackbar),
        findsOneWidget,
      );
      expect(find.textContaining('PDF ready'), findsOneWidget);
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

      expect(calls.any((c) => c.startsWith('buildCsv:')), isTrue);
      expect(calls.any((c) => c.startsWith('shareCsv:')), isTrue);
      expect(
        find.byKey(QaTestKeys.financeReportExportSuccessSnackbar),
        findsOneWidget,
      );
      expect(find.textContaining('Excel CSV ready'), findsOneWidget);
    });
  });
}
