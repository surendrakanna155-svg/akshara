import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/reports/amount_in_words.dart';
import '../../../theme/spacing.dart';
import 'fee_certificate_models.dart';

/// PAR-D3 — renders an annual (Section 80C) fee-payment certificate PDF from the
/// backend's [FeeCertificateData]. Mirrors the finance receipt / admissions
/// offer-letter PDF pattern (build a `pw.Document`, then `Printing.layoutPdf` /
/// `Printing.sharePdf`) so print and share behave identically across the app.
///
/// [buildCertificatePdf] is plugin-free (pure bytes) so it is unit-testable
/// without the printing platform channel; [printCertificate] / [shareCertificate]
/// route through injectable hooks that default to [Printing].
class ParentFeeCertificatePdfService {
  ParentFeeCertificatePdfService({
    Future<void> Function(Uint8List bytes)? layoutPdf,
    Future<void> Function({required Uint8List bytes, required String filename})?
        sharePdf,
  })  : _layoutPdf = layoutPdf ??
            ((bytes) => Printing.layoutPdf(onLayout: (_) async => bytes)),
        _sharePdf = sharePdf ??
            (({required bytes, required filename}) =>
                Printing.sharePdf(bytes: bytes, filename: filename));

  final Future<void> Function(Uint8List bytes) _layoutPdf;
  final Future<void> Function({
    required Uint8List bytes,
    required String filename,
  }) _sharePdf;

  Future<Uint8List> buildCertificatePdf(FeeCertificateData data) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AksharaSpacing.s6),
        build: (context) => _certificatePage(data),
      ),
    );
    return document.save();
  }

  Future<void> printCertificate(Uint8List bytes) => _layoutPdf(bytes);

  Future<void> shareCertificate({
    required Uint8List bytes,
    required String academicYear,
  }) {
    final safeYear = academicYear.trim().isEmpty
        ? 'certificate'
        : academicYear.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return _sharePdf(bytes: bytes, filename: 'fee_certificate_$safeYear.pdf');
  }

  /// A safe file name for the certificate (public for the UI action).
  static String fileNameFor(String academicYear) {
    final safeYear = academicYear.trim().isEmpty
        ? 'certificate'
        : academicYear.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return 'fee_certificate_$safeYear.pdf';
  }

  List<pw.Widget> _certificatePage(FeeCertificateData data) {
    final identity = <String>[
      if ((data.publicStudentId ?? '').isNotEmpty)
        'Public ID ${data.publicStudentId}',
      if ((data.admissionNumber ?? '').isNotEmpty)
        'Admission ${data.admissionNumber}',
    ].join(', ');
    final identitySuffix = identity.isEmpty ? '' : ' ($identity)';
    final totalRupees = data.totalPaidAmount.round();

    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _logoPlaceholder(),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  data.schoolName,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'FEE PAYMENT CERTIFICATE (Section 80C)',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      pw.Divider(),
      pw.SizedBox(height: 8),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Academic Year: ${data.academicYear}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        'To Whomsoever It May Concern',
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        'This is to certify that a total of ${_formatInr(totalRupees)} '
        '(${rupeesInWords(totalRupees)}) was paid towards '
        '${data.studentName}$identitySuffix for the academic year '
        '${data.academicYear}.',
        style: const pw.TextStyle(fontSize: 11),
      ),
      if (data.guardianName.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text(
          'Payments were received from ${data.guardianName}.',
          style: const pw.TextStyle(fontSize: 11),
        ),
      ],
      pw.SizedBox(height: 16),
      _paymentsSection(data),
      pw.SizedBox(height: 16),
      pw.Text(
        'This certificate is issued for the purpose of claiming a deduction '
        'under Section 80C of the Income Tax Act, 1961, where applicable.',
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.SizedBox(height: 40),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 160,
                child: pw.Divider(color: PdfColors.grey600),
              ),
              pw.Text(
                data.signatoryTitle.isEmpty ? 'Principal' : data.signatoryTitle,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'This is a computer-generated certificate.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    ];
  }

  pw.Widget _paymentsSection(FeeCertificateData data) {
    if (data.payments.isEmpty) {
      return pw.Text(
        'No payments were recorded for the academic year ${data.academicYear}.',
        style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.TableHelper.fromTextArray(
          headers: const ['Date', 'Receipt', 'Method', 'Amount'],
          data: [
            for (final p in data.payments)
              [
                p.date,
                p.receiptNo,
                p.paymentMethod,
                _formatInr(p.amount.round()),
              ],
          ],
          border: pw.TableBorder.all(color: PdfColors.grey400),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
          cellAlignments: const {3: pw.Alignment.centerRight},
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Total Paid: ${_formatInr(data.totalPaidAmount.round())}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }

  pw.Widget _logoPlaceholder() => pw.Container(
        width: 60,
        height: 60,
        decoration:
            pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
        alignment: pw.Alignment.center,
        child: pw.Text('LOGO',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      );

  String _formatInr(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer(amount < 0 ? '-INR ' : 'INR ');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

final parentFeeCertificatePdfServiceProvider =
    Provider<ParentFeeCertificatePdfService>(
  (ref) => ParentFeeCertificatePdfService(),
);
