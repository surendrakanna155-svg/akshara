import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../theme/spacing.dart';
import '../sis_models.dart';

/// SIS-1 — renders a formal student certificate PDF (bonafide / study / conduct
/// / transfer) from the backend's [SisCertificateData]. Mirrors the admissions
/// offer-letter pattern (school letterhead, a title per type, a key/value body,
/// and a signatory line), then prints/shares via the Printing plugin so print
/// and share behave identically with the rest of the app.
class SisCertificatePdfService {
  const SisCertificatePdfService();

  Future<Uint8List> buildCertificatePdf({
    required SisCertificateData data,
    String signatoryName = 'Principal',
  }) async {
    final schoolName =
        data.schoolName.trim().isEmpty ? 'Akshara School' : data.schoolName.trim();
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AksharaSpacing.s6),
        build: (context) => _certificatePage(
          data: data,
          schoolName: schoolName,
          signatoryName: signatoryName,
        ),
      ),
    );
    return document.save();
  }

  Future<void> printCertificate(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareCertificate({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  /// A stable, human-readable file name for a certificate (used when sharing).
  static String fileNameFor(SisCertificateData data) {
    final safeName = data.studentName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final slug = safeName.isEmpty ? 'student' : safeName;
    return '${data.type.apiValue}_certificate_$slug.pdf';
  }

  List<pw.Widget> _certificatePage({
    required SisCertificateData data,
    required String schoolName,
    required String signatoryName,
  }) {
    final isTransfer = data.type == SisCertificateType.transfer;
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
                  data.type.certificateTitle,
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          if (isTransfer && (data.serialNo?.isNotEmpty ?? false))
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Serial No.',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
                pw.Text(data.serialNo!,
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
        ],
      ),
      pw.Divider(),
      pw.SizedBox(height: 16),
      pw.Center(
        child: pw.Text(
          data.type.certificateTitle.toUpperCase(),
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.SizedBox(height: 16),
      pw.Text(
        _bodyText(data, isTransfer: isTransfer),
        style: const pw.TextStyle(fontSize: 11),
      ),
      pw.SizedBox(height: 16),
      _kv('Student name', data.studentName),
      _kv('Public ID',
          (data.publicStudentId?.isNotEmpty ?? false) ? data.publicStudentId! : '—'),
      _kv('Admission number',
          data.admissionNumber.isEmpty ? '—' : data.admissionNumber),
      _kv('Class',
          data.className.isEmpty ? '—' : '${data.className}${data.section.isEmpty ? '' : '-${data.section}'}'),
      _kv('Academic year', data.academicYear.isEmpty ? '—' : data.academicYear),
      _kv('Date of birth', data.dateOfBirth.isEmpty ? '—' : data.dateOfBirth),
      _kv('Guardian', data.guardianName.isEmpty ? '—' : data.guardianName),
      if (isTransfer && (data.serialNo?.isNotEmpty ?? false))
        _kv('TC serial', data.serialNo!),
      if (data.reason?.isNotEmpty ?? false) _kv('Reason', data.reason!),
      pw.SizedBox(height: 20),
      pw.Text(
        isTransfer
            ? 'This certifies that the above-named student has been relieved from '
                'this institution. We wish the student success in future endeavours.'
            : 'This certificate is issued on request for official purposes.',
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
        'This is a computer-generated certificate.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    ];
  }

  String _bodyText(SisCertificateData data, {required bool isTransfer}) {
    final name = data.studentName.isEmpty ? 'the student' : data.studentName;
    final classLabel = data.className.isEmpty
        ? ''
        : ' of class ${data.className}${data.section.isEmpty ? '' : '-${data.section}'}';
    if (isTransfer) {
      return 'This is to certify that $name$classLabel, bearing admission number '
          '${data.admissionNumber.isEmpty ? '—' : data.admissionNumber}, has '
          'been a bonafide student of this institution and is hereby granted a '
          'Transfer Certificate. All dues have been cleared.';
    }
    return 'This is to certify that $name$classLabel, bearing admission number '
        '${data.admissionNumber.isEmpty ? '—' : data.admissionNumber}, is a '
        'bonafide student of this institution for the academic year '
        '${data.academicYear.isEmpty ? '—' : data.academicYear}.';
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
