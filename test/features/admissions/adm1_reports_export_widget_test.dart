import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/admissions/reports/admissions_reports_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// ADM-1 — the admissions reports screen exports the selected tab as BOTH CSV
/// and PDF through the shared AksharaReportExportService (the export service is
/// faked so the platform `printing` plugin is never driven; each call is
/// recorded so we can assert the export path fired).
class _FakeExportService extends AksharaReportExportService {
  const _FakeExportService(this.calls);

  final List<String> calls;

  @override
  Future<void> shareGridCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    calls.add('csv:$filename:${rows.length}');
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
    calls.add('pdf:$filename:${rows.length}');
  }
}

Future<void> _pump(WidgetTester tester, List<String> calls) async {
  tester.view.physicalSize = const Size(1440, 900);
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
        home: const AdmissionsReportsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ADM-1 · tapping Export PDF fires a grid PDF through the shared service',
      (tester) async {
    final calls = <String>[];
    await _pump(tester, calls);

    final pdfBtn = find.byKey(QaTestKeys.admissionsReportExportPdfButton);
    await tester.ensureVisible(pdfBtn);
    await tester.tap(pdfBtn);
    await tester.pumpAndSettle();

    expect(calls.any((c) => c.startsWith('pdf:admissions_funnel')), isTrue);
  });

  testWidgets('ADM-1 · tapping Export CSV fires a grid CSV through the shared service',
      (tester) async {
    final calls = <String>[];
    await _pump(tester, calls);

    final csvBtn = find.byKey(QaTestKeys.admissionsReportExportCsvButton);
    await tester.ensureVisible(csvBtn);
    await tester.tap(csvBtn);
    await tester.pumpAndSettle();

    expect(calls.any((c) => c.startsWith('csv:admissions_funnel')), isTrue);
  });
}
