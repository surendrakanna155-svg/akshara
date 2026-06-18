import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../audit/audit_event.dart';

/// Shared PDF/CSV export scaffold (P0-FIN-003 / RPT-018).
class AksharaReportExportService {
  const AksharaReportExportService();

  String buildTabularReportCsv({
    required String reportTitle,
    required List<MapEntry<String, String>> rows,
  }) {
    final buffer = StringBuffer()
      ..writeln('Report,$reportTitle')
      ..writeln('Field,Value');
    for (final row in rows) {
      buffer.writeln('${_escapeCsv(row.key)},${_escapeCsv(row.value)}');
    }
    return buffer.toString();
  }

  Uint8List buildTabularReportCsvBytes({
    required String reportTitle,
    required List<MapEntry<String, String>> rows,
  }) {
    return Uint8List.fromList(
      utf8.encode(buildTabularReportCsv(reportTitle: reportTitle, rows: rows)),
    );
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<Uint8List> buildTabularReportPdf({
    required String reportTitle,
    required String moduleLabel,
    required List<MapEntry<String, String>> rows,
    String? generatedAtLabel,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            reportTitle,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(moduleLabel, style: const pw.TextStyle(fontSize: 12)),
          if (generatedAtLabel != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated: $generatedAtLabel',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Field', 'Value'],
            data: [
              for (final row in rows) [row.key, row.value],
            ],
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<void> previewPdf({
    required String documentName,
    required Uint8List bytes,
  }) {
    return Printing.layoutPdf(
      name: documentName,
      onLayout: (_) async => bytes,
    );
  }

  Future<void> shareTabularCsv({
    required String filename,
    required String reportTitle,
    required List<MapEntry<String, String>> rows,
  }) {
    final bytes = buildTabularReportCsvBytes(
      reportTitle: reportTitle,
      rows: rows,
    );
    final name = filename.endsWith('.csv') ? filename : '$filename.csv';
    return Printing.sharePdf(bytes: bytes, filename: name);
  }
}

final aksharaReportExportServiceProvider = Provider<AksharaReportExportService>(
  (ref) => const AksharaReportExportService(),
);
