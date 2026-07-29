import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AksharaReportExportService CSV', () {
    const service = AksharaReportExportService();

    test('buildTabularReportCsv escapes commas and quotes', () {
      final csv = service.buildTabularReportCsv(
        reportTitle: 'Collections',
        rows: [
          const MapEntry('Report ID', 'fin_collections'),
          const MapEntry('Notes', 'Value, with "quotes"'),
        ],
      );

      expect(csv, contains('Report,Collections'));
      expect(csv, contains('"Value, with ""quotes"""'));
    });

    test('buildTabularReportCsvBytes returns utf8 bytes', () {
      final bytes = service.buildTabularReportCsvBytes(
        reportTitle: 'Refunds',
        rows: [const MapEntry('Count', '3')],
      );
      expect(String.fromCharCodes(bytes), contains('Refunds'));
    });
  });

  group('AksharaReportExportService grid (XCT-1)', () {
    const service = AksharaReportExportService();

    test('buildGridReportCsv emits header row + one row per record', () {
      final csv = service.buildGridReportCsv(
        headers: const ['Source', 'Leads', 'Converted'],
        rows: const [
          ['Website', '40', '12'],
          ['Referral', '25', '9'],
        ],
      );
      final lines = csv.trim().split('\n');
      expect(lines.length, 3); // header + 2 data rows
      expect(lines.first, 'Source,Leads,Converted');
      expect(lines[1], 'Website,40,12');
    });

    test('buildGridReportCsv escapes commas and quotes in any column', () {
      final csv = service.buildGridReportCsv(
        headers: const ['Item', 'Note'],
        rows: const [
          ['Chalk, box', 'has "quotes"'],
        ],
      );
      expect(csv, contains('"Chalk, box","has ""quotes"""'));
    });

    test('buildGridReportCsvBytes returns utf8 bytes', () {
      final bytes = service.buildGridReportCsvBytes(
        headers: const ['A', 'B'],
        rows: const [
          ['1', '2'],
        ],
      );
      expect(String.fromCharCodes(bytes), contains('A,B'));
    });

    test('buildGridReportPdf produces a non-empty PDF document', () async {
      final bytes = await service.buildGridReportPdf(
        reportTitle: 'Tabulation Register',
        moduleLabel: 'Exams',
        headers: const ['Student', 'Maths', 'Science', 'Total'],
        rows: const [
          ['Asha', '88', '91', '179'],
          ['Ravi', '76', '84', '160'],
        ],
        rightAlignFrom: 1,
      );
      expect(bytes.length, greaterThan(0));
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });

    test('HR-2 · buildPayslipPdf produces a non-empty single-employee PDF',
        () async {
      final bytes = await service.buildPayslipPdf(
        schoolName: 'NIKSHA Public School',
        period: 'May 2026',
        employeeName: 'Mrs. Rao',
        employeeCode: 'HR-EMP-102',
        department: 'Academics',
        earnings: const [
          MapEntry('Basic', '40000'),
          MapEntry('Allowances', '8000'),
        ],
        deductions: const [MapEntry('PF', '4800')],
        grossEarnings: '48000',
        totalDeductions: '4800',
        netPay: '43200',
      );
      expect(bytes.length, greaterThan(0));
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
