import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/director/director_models.dart';
import '../../features/parent/receipts/receipt_models.dart';
import '../exams/exam_remark.dart';
import '../exams/exam_report_card.dart';
import '../../theme/spacing.dart';

/// Shared PDF/CSV export scaffold (P0-FIN-003 / RPT-018).
class AksharaReportExportService {
  const AksharaReportExportService();

  /// Builds a fee-receipt PDF (school branding placeholder, payer details, line
  /// items, total, payment method, status).
  Future<Uint8List> buildReceiptPdf({required FeeReceipt receipt}) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AksharaSpacing.s7),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(receipt.schoolName,
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('Fee Receipt', style: const pw.TextStyle(fontSize: 12)),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Receipt No: ${receipt.receiptNumber}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text(receipt.dateLabel,
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('${receipt.childName} · ${receipt.childClass}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: const ['Item', 'Amount'],
              data: [
                for (final line in receipt.lineItems)
                  [line.label, '${line.amount}'],
                ['Total', '${receipt.amount}'],
              ],
              border: pw.TableBorder.all(color: PdfColors.grey400),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellAlignments: const {1: pw.Alignment.centerRight},
            ),
            pw.SizedBox(height: 12),
            pw.Text('Payment method: ${receipt.paymentMethod}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Status: ${receipt.statusLabel}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
    return document.save();
  }

  Future<void> shareReceiptPdf({required FeeReceipt receipt}) async {
    final bytes = await buildReceiptPdf(receipt: receipt);
    final name = 'receipt_${receipt.receiptNumber}.pdf'.replaceAll(' ', '_');
    await Printing.sharePdf(bytes: bytes, filename: name);
  }

  /// HR-2 — a single employee's payslip as its own printable document (mirrors
  /// [buildReceiptPdf]). Earnings and deductions render as two tables with the
  /// net pay called out. Amounts are pre-formatted strings (the caller owns the
  /// money formatting); [schoolName] heads the slip when provided. Decoupled
  /// from the HR domain models on purpose — primitive params only.
  Future<Uint8List> buildPayslipPdf({
    String? schoolName,
    required String period,
    required String employeeName,
    required String employeeCode,
    required String department,
    required List<MapEntry<String, String>> earnings,
    required List<MapEntry<String, String>> deductions,
    required String grossEarnings,
    required String totalDeductions,
    required String netPay,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AksharaSpacing.s7),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              (schoolName != null && schoolName.isNotEmpty)
                  ? schoolName
                  : 'Payslip',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text('Salary Slip · $period',
                style: const pw.TextStyle(fontSize: 12)),
            pw.Divider(color: PdfColors.grey400),
            pw.Text('$employeeName ($employeeCode)',
                style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Department: $department',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 14),
            pw.Text('Earnings',
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: const ['Component', 'Amount'],
              data: [
                for (final e in earnings) [e.key, e.value],
                ['Gross earnings', grossEarnings],
              ],
              border: pw.TableBorder.all(color: PdfColors.grey400),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellAlignments: const {1: pw.Alignment.centerRight},
            ),
            pw.SizedBox(height: 12),
            pw.Text('Deductions',
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: const ['Component', 'Amount'],
              data: [
                for (final d in deductions) [d.key, d.value],
                ['Total deductions', totalDeductions],
              ],
              border: pw.TableBorder.all(color: PdfColors.grey400),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellAlignments: const {1: pw.Alignment.centerRight},
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Net pay',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(netPay,
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }

  Future<void> sharePayslipPdf({
    String? schoolName,
    required String period,
    required String employeeName,
    required String employeeCode,
    required String department,
    required List<MapEntry<String, String>> earnings,
    required List<MapEntry<String, String>> deductions,
    required String grossEarnings,
    required String totalDeductions,
    required String netPay,
  }) async {
    final bytes = await buildPayslipPdf(
      schoolName: schoolName,
      period: period,
      employeeName: employeeName,
      employeeCode: employeeCode,
      department: department,
      earnings: earnings,
      deductions: deductions,
      grossEarnings: grossEarnings,
      totalDeductions: totalDeductions,
      netPay: netPay,
    );
    final name = 'payslip_${employeeCode}_$period.pdf'
        .replaceAll(RegExp(r'[^A-Za-z0-9_.]+'), '_');
    await Printing.sharePdf(bytes: bytes, filename: name);
  }

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
    document.addPage(_reportCardPage(
      card: card,
      schoolName: schoolName,
      generatedAtLabel: generatedAtLabel,
    ));
    return document.save();
  }

  /// The single report-card page (shared by [buildReportCardPdf] and the EXM-D1
  /// batch builder so a printed bundle is byte-for-byte the same layout).
  pw.Page _reportCardPage({
    required ExamReportCard card,
    required String schoolName,
    String? generatedAtLabel,
  }) {
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

    return pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AksharaSpacing.s7),
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
            if ((card.remark ?? '').isNotEmpty)
              ..._remarkBlock(
                title: (card.remarkAuthorRole ??
                        ExamRemarkAuthorRole.classTeacher)
                    .reportCardRemarkTitle,
                text: card.remark!,
                authorName: card.remarkAuthorName,
              ),
            if ((card.leadershipRemark ?? '').isNotEmpty)
              ..._remarkBlock(
                title: (card.leadershipRemarkAuthorRole ??
                        ExamRemarkAuthorRole.principal)
                    .reportCardRemarkTitle,
                text: card.leadershipRemark!,
                authorName: card.leadershipRemarkAuthorName,
              ),
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
    );
  }

  /// A titled report-card remark block (text box + optional author byline).
  List<pw.Widget> _remarkBlock({
    required String title,
    required String text,
    String? authorName,
  }) {
    return [
      pw.SizedBox(height: 14),
      pw.Text(title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(AksharaSpacing.s2),
        decoration:
            pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
      ),
      if ((authorName ?? '').isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text('— $authorName',
              style:
                  const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ),
    ];
  }

  /// EXM-D1 — builds a single multi-page report-card PDF, ONE card per page, from
  /// a batch of already-computed [cards] (published results for a class + term).
  /// Reuses the exact single-card layout ([_reportCardPage]) so a printed bundle
  /// is identical to a single card. Rank is shown only when [rankShown].
  Future<Uint8List> buildBatchReportCardsPdf({
    required List<ExamReportCard> cards,
    required String schoolName,
    String? generatedAtLabel,
  }) async {
    final document = pw.Document();
    for (final card in cards) {
      document.addPage(_reportCardPage(
        card: card,
        schoolName: schoolName,
        generatedAtLabel: generatedAtLabel,
      ));
    }
    return document.save();
  }

  /// EXM-D4 — builds a single multi-page hall-ticket (admit-card) PDF, ONE ticket
  /// per page, for a class/exam. Standard template: school header, student, exam
  /// details, instructions.
  Future<Uint8List> buildHallTicketsPdf({
    required List<HallTicketPrintData> tickets,
    required String schoolName,
    String? generatedAtLabel,
  }) async {
    final document = pw.Document();
    for (final t in tickets) {
      document.addPage(_hallTicketPage(
        ticket: t,
        schoolName: schoolName,
        generatedAtLabel: generatedAtLabel,
      ));
    }
    return document.save();
  }

  pw.Page _hallTicketPage({
    required HallTicketPrintData ticket,
    required String schoolName,
    String? generatedAtLabel,
  }) {
    pw.Widget detail(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(children: [
            pw.SizedBox(
              width: 90,
              child: pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
            ),
            pw.Expanded(
                child:
                    pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
          ]),
        );

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(AksharaSpacing.s7),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(schoolName,
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Hall Ticket / Admit Card',
              style: const pw.TextStyle(fontSize: 12)),
          pw.Divider(color: PdfColors.grey400),
          detail('Student', ticket.studentName),
          detail('Roll No', ticket.rollNo ?? '—'),
          detail('Class', ticket.classLabel),
          detail('Student ID', ticket.sisStudentId),
          pw.SizedBox(height: 8),
          detail('Exam', ticket.examTitle),
          detail('Subject', ticket.subject),
          detail('Date', ticket.dateLabel),
          detail('Time', ticket.timeLabel),
          detail('Venue', ticket.venueLabel),
          detail('Max marks', '${ticket.maxMarks}'),
          pw.SizedBox(height: 14),
          pw.Text('Instructions',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          for (final line in ticket.instructions)
            pw.Bullet(text: line, style: const pw.TextStyle(fontSize: 10)),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                width: 130,
                height: 44,
                decoration:
                    pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                alignment: pw.Alignment.center,
                child: pw.Text('Invigilator signature',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
              ),
              pw.Container(
                width: 110,
                height: 44,
                decoration:
                    pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                alignment: pw.Alignment.center,
                child: pw.Text('School seal',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
              ),
            ],
          ),
          if (generatedAtLabel != null) ...[
            pw.SizedBox(height: 8),
            pw.Text('Generated: $generatedAtLabel',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey600)),
          ],
        ],
      ),
    );
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
        margin: const pw.EdgeInsets.all(AksharaSpacing.s6),
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

  /// Builds the Director board-pack PDF from a server-assembled [DirectorBoardPack]
  /// (live, org-wide aggregates — school-level only, no student/parent PII).
  Future<Uint8List> buildDirectorBoardPackPdf(DirectorBoardPack pack) async {
    final document = pw.Document();
    final g = pack.generatedAt;
    final generatedLabel =
        '${g.year}-${g.month.toString().padLeft(2, '0')}-${g.day.toString().padLeft(2, '0')}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AksharaSpacing.s7),
        build: (context) => [
          pw.Text(pack.title,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(pack.description, style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 2),
          pw.Text('Generated: $generatedLabel · Aggregated data only · No student PII',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 6),
          pw.Text('Executive summary',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(pack.executiveSummary, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 14),
          pw.Text('Portfolio KPIs',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: const ['Metric', 'Value'],
            data: [for (final k in pack.kpis) [k.label, k.value]],
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: const {1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 14),
          pw.Text('Financials (₹ Cr)',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: const ['Field', 'Value'],
            data: [
              ['Chain revenue', '${pack.chainRevenueCr} Cr'],
              ['Expenses', '${pack.expensesCr} Cr'],
              ['Net', '${pack.netCr} Cr'],
              ['Margin', '${pack.marginPercent}%'],
              ['Forecast', '${pack.forecastCr} Cr'],
              ['Admissions conversion', '${pack.conversionPercent}% (${pack.enrolled}/${pack.inquiries})'],
              ['Net student growth', '${pack.netGrowth}'],
              ['Capacity utilization', '${pack.capacityPercent}%'],
              ['Marketing spend', '${pack.totalSpendLakhs} L'],
              ['Marketing ROI', '${pack.roiPercent}%'],
              ['Compliance overdue', '${pack.complianceOverdue} of ${pack.complianceTotal}'],
            ],
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: const {1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 14),
          pw.Text('Schools',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: const ['School', 'Students', 'Revenue', 'Fee %', 'Health'],
            data: [
              for (final s in pack.schools)
                [
                  s.schoolName,
                  '${s.students}',
                  '${s.revenueCr} Cr',
                  '${s.feeCollectionPercent}%',
                  '${s.healthScore}',
                ],
            ],
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: const {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );
    return document.save();
  }

  /// Builds and opens the OS share sheet for a Director board-pack PDF.
  Future<void> shareDirectorBoardPackPdf(DirectorBoardPack pack) async {
    final bytes = await buildDirectorBoardPackPdf(pack);
    final name = '${pack.title}_${pack.reportId}'
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_');
    await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
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

  // --- Multi-column grid exports (XCT-1) --------------------------------------
  // The key/value builders above collapse a record into "Field,Value" pairs.
  // Real module reports (tabulation register students×subjects, monthly muster
  // employee×day, transaction-level day collection, salary register) need a
  // proper grid: one header row + one data row per record. These are the shared
  // primitive every such report rides on — no module invents its own.

  /// Builds a multi-column grid CSV (header row + one row per record).
  String buildGridReportCsv({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final buffer = StringBuffer()..writeln(headers.map(_escapeCsv).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsv).join(','));
    }
    return buffer.toString();
  }

  Uint8List buildGridReportCsvBytes({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return Uint8List.fromList(
      utf8.encode(buildGridReportCsv(headers: headers, rows: rows)),
    );
  }

  Future<void> shareGridCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final bytes = buildGridReportCsvBytes(headers: headers, rows: rows);
    final name = filename.endsWith('.csv') ? filename : '$filename.csv';
    return Printing.sharePdf(bytes: bytes, filename: name);
  }

  /// XCT-1 — the ONE styled table primitive every module's grid/tabular PDF
  /// rides. A single place for the border / header / cell styling so a table in
  /// a finance export, a management dashboard, an operations report, or the
  /// audit register all render identically. Columns at index [rightAlignFrom]
  /// and beyond are right-aligned (for numeric/amount columns).
  pw.Widget buildGridTable({
    required List<String> headers,
    required List<List<String>> rows,
    int? rightAlignFrom,
  }) {
    final Map<int, pw.Alignment> cellAlignments = {};
    if (rightAlignFrom != null) {
      for (var i = rightAlignFrom; i < headers.length; i++) {
        cellAlignments[i] = pw.Alignment.centerRight;
      }
    }
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey400),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: cellAlignments,
      cellStyle: const pw.TextStyle(fontSize: 9),
    );
  }

  /// Builds a multi-column grid PDF (paginated table). Columns at index
  /// [rightAlignFrom] and beyond are right-aligned (for numeric/amount columns).
  Future<Uint8List> buildGridReportPdf({
    required String reportTitle,
    required String moduleLabel,
    required List<String> headers,
    required List<List<String>> rows,
    String? generatedAtLabel,
    int? rightAlignFrom,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AksharaSpacing.s6),
        build: (context) => [
          pw.Text(
            reportTitle,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(moduleLabel, style: const pw.TextStyle(fontSize: 12)),
          if (generatedAtLabel != null) ...[
            pw.SizedBox(height: 4),
            pw.Text('Generated: $generatedAtLabel',
                style: const pw.TextStyle(fontSize: 10)),
          ],
          pw.SizedBox(height: 16),
          buildGridTable(
            headers: headers,
            rows: rows,
            rightAlignFrom: rightAlignFrom,
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<void> shareGridPdf({
    required String filename,
    required String reportTitle,
    required String moduleLabel,
    required List<String> headers,
    required List<List<String>> rows,
    String? generatedAtLabel,
    int? rightAlignFrom,
  }) async {
    final bytes = await buildGridReportPdf(
      reportTitle: reportTitle,
      moduleLabel: moduleLabel,
      headers: headers,
      rows: rows,
      generatedAtLabel: generatedAtLabel,
      rightAlignFrom: rightAlignFrom,
    );
    final name = filename.endsWith('.pdf') ? filename : '$filename.pdf';
    await Printing.sharePdf(bytes: bytes, filename: name);
  }
}

final aksharaReportExportServiceProvider = Provider<AksharaReportExportService>(
  (ref) => const AksharaReportExportService(),
);

/// EXM-D4 — a print-ready hall ticket (admit card). A plain view-model so the
/// export service stays decoupled from the exam domain models; the UI maps a
/// [HallTicket] onto this before printing.
class HallTicketPrintData {
  const HallTicketPrintData({
    required this.sisStudentId,
    required this.studentName,
    required this.rollNo,
    required this.classLabel,
    required this.subject,
    required this.examTitle,
    required this.dateLabel,
    required this.timeLabel,
    required this.venueLabel,
    required this.maxMarks,
    required this.instructions,
  });

  final String sisStudentId;
  final String studentName;
  final String? rollNo;
  final String classLabel;
  final String subject;
  final String examTitle;
  final String dateLabel;
  final String timeLabel;
  final String venueLabel;
  final int maxMarks;
  final List<String> instructions;
}
