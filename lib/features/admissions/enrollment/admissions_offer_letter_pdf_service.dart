import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../theme/spacing.dart';
import '../admissions_models.dart';

/// ADM-D4: renders an admission offer letter PDF from the backend's
/// [OfferLetterData]. Mirrors the finance receipt-PDF pattern (build a
/// `pw.Document`, then `Printing.layoutPdf` / `Printing.sharePdf`) so print and
/// share behave identically across the app.
class AdmissionsOfferLetterPdfService {
  const AdmissionsOfferLetterPdfService();

  Future<Uint8List> buildOfferLetterPdf({
    required OfferLetterData data,
    String schoolName = 'NIKSHA School',
    String signatoryName = 'Principal',
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AksharaSpacing.s6),
        build: (context) => _offerLetterPage(
          data: data,
          schoolName: schoolName,
          signatoryName: signatoryName,
        ),
      ),
    );
    return document.save();
  }

  Future<void> printOfferLetter(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareOfferLetter({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  List<pw.Widget> _offerLetterPage({
    required OfferLetterData data,
    required String schoolName,
    required String signatoryName,
  }) {
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
                  schoolName,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Admission Offer Letter',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      pw.Divider(),
      pw.SizedBox(height: 8),
      pw.Text(
        'Dear ${data.guardianName},',
        style: const pw.TextStyle(fontSize: 12),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'We are pleased to offer admission to ${data.studentName} for the '
        'academic year ${data.academicYear}. Please find the confirmed '
        'admission details below.',
        style: const pw.TextStyle(fontSize: 11),
      ),
      pw.SizedBox(height: 16),
      _kv('Student name', data.studentName),
      _kv('Admission number', data.admissionNumber),
      _kv('Class', data.className),
      _kv('Section', data.section.isEmpty ? '—' : data.section),
      _kv('Academic year', data.academicYear),
      _kv('Guardian', data.guardianName),
      _kv('Reporting date', data.reportingDateLabel),
      if (data.recommendedFeePlanId != null &&
          data.recommendedFeePlanId!.isNotEmpty)
        _kv('Fee plan', data.recommendedFeePlanId!),
      pw.SizedBox(height: 20),
      pw.Text(
        'Kindly report to the school office on the reporting date with the '
        'required documents to complete the joining formalities.',
        style: const pw.TextStyle(fontSize: 11),
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
              pw.Text(signatoryName,
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'This is a computer-generated offer letter.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    ];
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

  pw.Widget _kv(String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: AksharaSpacing.s1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              '$key:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
}
