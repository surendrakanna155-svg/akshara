import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../exams/exam_report_card.dart';

/// Shared PDF/CSV export scaffold (P0-FIN-003 / RPT-018).
class AksharaReportExportService {
  const AksharaReportExportService();

  /// Builds a printable report-card PDF. Layout is identical across grading
  /// systems (it renders the already-computed grade strings). Rank is included
  /// only when the school allows it ([ExamReportCard.rankShown]). Logo, principal
  /// signature, and school seal are placeholders until assets are wired.
  Future<Uint8List> buildReportCardPdf({
    required ExamReportCard card,
    required String schoolName,
    String? generatedAtLabel,
  }) async {
    final document = pw.Document();

    pw.Widget detail(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(children: [
            pw.SizedBox(
              width: 90,
              child: pw.Text(label,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ),
            pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ]),
        );

    pw.Widget placeholderBox(String label) => pw.Container(
          width: 110,
          height: 56,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Branding header (logo placeholder + school name).
            pw.Row(children: [
              placeholderBox('LOGO'),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(schoolName,
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Report Card · ${card.termLabel}',
                        style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ]),
            pw.Divider(color: PdfColors.grey400),
            // Student details.
            detail('Student', card.studentName),
            detail('Class / Section', card.classLabel),
            detail('Student ID', card.sisStudentId),
            if (card.attendancePercent != null)
              detail('Attendance', '${card.attendancePercent}%'),
            if (card.rankShown) detail('Rank', '${card.rank} of ${card.classSize}'),
            pw.SizedBox(height: 14),
            // Subject-wise marks.
            pw.TableHelper.fromTextArray(
              headers: const ['Subject', 'Marks', '%', 'Grade'],
              data: [
                for (final s in card.subjects)
                  [s.subject, '${s.score}/${s.maxScore}', '${s.percent}%', s.grade],
                [
                  'Total',
                  '${card.totalScore}/${card.totalMax}',
                  '${card.overallPercent}%',
                  card.overallGrade,
                ],
              ],
              border: pw.TableBorder.all(color: PdfColors.grey400),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: const {
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
              },
            ),
            if ((card.remark ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text('Class teacher remark',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration:
                    pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                child: pw.Text(card.remark!,
                    style: const pw.TextStyle(fontSize: 10)),
              ),
              if ((card.remarkAuthorName ?? '').isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text('— ${card.remarkAuthorName}',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ),
            ],
            pw.Spacer(),
            // Signature + seal placeholders.
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                placeholderBox('Principal\nsignature'),
                placeholderBox('School\nseal'),
              ],
            ),
            if (generatedAtLabel != null) ...[
              pw.SizedBox(height: 8),
              pw.Text('Generated: $generatedAtLabel',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ],
        ),
      ),
    );
    return document.save();
  }

  /// Builds and opens the OS share sheet for a report card PDF.
  Future<void> shareReportCardPdf({
    required ExamReportCard card,
    required String schoolName,
    String? generatedAtLabel,
  }) async {
    final bytes = await buildReportCardPdf(
      card: card,
      schoolName: schoolName,
      generatedAtLabel: generatedAtLabel,
    );
    final safeName =
        '${card.studentName}_${card.termLabel}_report_card'.replaceAll(' ', '_');
    await Printing.sharePdf(bytes: bytes, filename: '$safeName.pdf');
  }

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
