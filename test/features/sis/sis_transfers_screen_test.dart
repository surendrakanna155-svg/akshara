import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_write_store.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/sis/reports/sis_report_exporters.dart';
import 'package:akshara_erp/features/sis/sis_models.dart';
import 'package:akshara_erp/features/sis/transfers/sis_transfers_provider.dart';
import 'package:akshara_erp/features/sis/transfers/sis_transfers_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpTransfers(
  WidgetTester tester, {
  List<Override> extra = const [],
}) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(extra),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const SisTransfersScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    MockSisWriteStore.instance.students = null;
    MockSisWriteStore.instance.conversionQueue = null;
    MockSisWriteStore.instance.studentDocuments = null;
  });

  group('SIS-5 transfers / exit-log screen', () {
    testWidgets('renders seeded exit rows with export + date-range controls',
        (tester) async {
      await _pumpTransfers(tester);

      expect(find.text('Rahul Verma'), findsOneWidget);
      expect(find.text('Sneha Gupta'), findsOneWidget);
      expect(find.text('Transferred'), findsWidgets);
      expect(find.text('Alumni'), findsWidgets);

      expect(
        find.byKey(QaTestKeys.sisTransfersDateRangeButton),
        findsOneWidget,
      );
      final csvButton = tester.widget<OutlinedButton>(
        find.byKey(QaTestKeys.sisTransfersExportCsvButton),
      );
      final pdfButton = tester.widget<OutlinedButton>(
        find.byKey(QaTestKeys.sisTransfersExportPdfButton),
      );
      expect(csvButton.enabled, isTrue);
      expect(pdfButton.enabled, isTrue);
    });

    testWidgets('status filter narrows the list to alumni', (tester) async {
      await _pumpTransfers(
        tester,
        extra: [
          sisTransfersStatusIndexProvider.overrideWith((ref) => 2),
        ],
      );

      expect(find.text('Sneha Gupta'), findsOneWidget);
      expect(find.text('Rahul Verma'), findsNothing);
    });

    testWidgets('date-range filter excludes rows outside the range',
        (tester) async {
      await _pumpTransfers(
        tester,
        extra: [
          sisTransfersRangeProvider.overrideWith(
            (ref) => const SisTransfersRange(
              fromDate: '2026-01-01',
              toDate: '2026-12-31',
            ),
          ),
        ],
      );

      // Rahul exited 2026-03-14 (in range); Sneha exited 2025-04-30 (outside).
      expect(find.text('Rahul Verma'), findsOneWidget);
      expect(find.text('Sneha Gupta'), findsNothing);
    });
  });

  group('SIS-5 transfers export grid (XCT-1)', () {
    const record = SisTransferRecord(
      studentId: 'stu-1',
      studentName: 'Rahul Verma',
      admissionNumber: 'ADM-2024-0031',
      classLabel: '9',
      section: 'B',
      academicYear: '2025–26',
      status: SisStudentStatus.transferred,
      exitedAt: '2026-03-14T09:30:00.000Z',
    );

    test('headers form the 8-column exit-log grid incl. reason', () {
      expect(SisReportExporters.transfersHeaders, const [
        'Student',
        'Admission #',
        'Class',
        'Section',
        'Academic year',
        'Status',
        'Exited at',
        'Reason',
      ]);
    });

    test('rows map record fields incl. status label and exit date', () {
      final rows = SisReportExporters.transfersRows(const [record]);
      expect(rows, hasLength(1));
      // No TC reason on this record -> blank Reason cell.
      expect(rows.single, const [
        'Rahul Verma',
        'ADM-2024-0031',
        '9',
        'B',
        '2025–26',
        'Transferred',
        '2026-03-14',
        '',
      ]);
    });

    test('SIS-5 reason column carries the latest TC reason when present', () {
      const withReason = SisTransferRecord(
        studentId: 'stu-2',
        studentName: 'Sneha Gupta',
        admissionNumber: 'ADM-2023-0009',
        classLabel: '10',
        section: 'A',
        academicYear: '2024–25',
        status: SisStudentStatus.alumni,
        exitedAt: '2025-04-30T00:00:00.000Z',
        reason: 'Relocation to another city',
      );
      final rows = SisReportExporters.transfersRows(const [withReason]);
      expect(rows.single.last, 'Relocation to another city');
    });

    test('grid CSV renders one header row + one row per record', () {
      const service = AksharaReportExportService();
      final csv = service.buildGridReportCsv(
        headers: SisReportExporters.transfersHeaders,
        rows: SisReportExporters.transfersRows(const [record]),
      );
      final lines = csv.trim().split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, contains('Admission #'));
      expect(lines.last, contains('Transferred'));
    });
  });
}
