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
}
