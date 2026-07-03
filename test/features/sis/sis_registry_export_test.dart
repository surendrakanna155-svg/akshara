import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_write_store.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/sis/registry/sis_registry_screen.dart';
import 'package:akshara_erp/features/sis/reports/sis_report_exporters.dart';
import 'package:akshara_erp/features/sis/sis_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

Future<void> _pumpRegistry(WidgetTester tester, {bool desktop = true}) async {
  if (desktop) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  } else {
    useMobileViewport(tester);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const SisRegistryScreen(),
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

  group('SIS-2 registry export grid (XCT-1)', () {
    const student = SisStudent(
      id: 'stu-1',
      studentName: 'Arjun Patel',
      admissionNumber: 'ADM-2026-0138',
      publicStudentId: 'DPSKKP-0001',
      classLabel: '10',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Male',
      dateOfBirth: '14 Jun 2011',
      guardianName: 'Kiran Patel',
      phone: '+91 98765 11111',
      email: 'kiran.patel@email.com',
      enrolledAt: 'Jan 2026',
    );

    test('headers form the 8-column registry grid incl. public ID + guardian',
        () {
      expect(SisReportExporters.registryHeaders, const [
        'Admission #',
        'Public ID',
        'Name',
        'Class',
        'Section',
        'Status',
        'Parent name',
        'Parent phone',
      ]);
    });

    test('rows carry public ID, guardian name and phone for each student', () {
      final rows = SisReportExporters.registryRows(const [student]);
      expect(rows, hasLength(1));
      expect(rows.single, const [
        'ADM-2026-0138',
        'DPSKKP-0001',
        'Arjun Patel',
        '10',
        'A',
        'Active',
        'Kiran Patel',
        '+91 98765 11111',
      ]);
    });

    test('public ID column renders "—" when the school has no code', () {
      const codeless = SisStudent(
        id: 'stu-2',
        studentName: 'No Code',
        admissionNumber: 'ADM-2026-0200',
        classLabel: '8',
        section: 'B',
        academicYear: '2026–27',
        status: SisStudentStatus.active,
        gender: 'Female',
        dateOfBirth: '01 Jan 2013',
        guardianName: 'Parent',
        phone: '+91 90000 00000',
        email: '',
        enrolledAt: 'Jan 2026',
      );
      final rows = SisReportExporters.registryRows(const [codeless]);
      expect(rows.single[1], '—');
    });

    test('grid CSV is a true multi-column grid, not key/value pairs', () {
      const service = AksharaReportExportService();
      final csv = service.buildGridReportCsv(
        headers: SisReportExporters.registryHeaders,
        rows: SisReportExporters.registryRows(const [student]),
      );
      final lines = csv.trim().split('\n');
      expect(lines, hasLength(2));
      expect(lines.first.split(',').length, 8);
      expect(lines.first, isNot(contains('Field')));
      expect(lines.last, contains('Kiran Patel'));
      expect(lines.last, contains('DPSKKP-0001'));
    });
  });

  group('SIS-2 registry screen export controls', () {
    testWidgets('shows enabled CSV and PDF export buttons', (tester) async {
      await _pumpRegistry(tester);

      final csvButton = tester.widget<OutlinedButton>(
        find.byKey(QaTestKeys.sisRegistryExportButton),
      );
      final pdfButton = tester.widget<OutlinedButton>(
        find.byKey(QaTestKeys.sisRegistryExportPdfButton),
      );
      expect(csvButton.enabled, isTrue);
      expect(pdfButton.enabled, isTrue);
    });

    testWidgets('mobile card subtitle shows the primary guardian contact',
        (tester) async {
      await _pumpRegistry(tester, desktop: false);

      expect(find.text('Kiran Patel · +91 98765 11111'), findsOneWidget);
    });
  });
}
