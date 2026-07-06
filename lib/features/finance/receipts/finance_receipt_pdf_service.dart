import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../finance_models.dart';
import '../../../core/reports/amount_in_words.dart';
import '../../../theme/spacing.dart';

/// A single receipt's data, so one-per-page batch printing (FIN-5) can reuse the
/// exact same layout as a single receipt (FIN-3).
class ReceiptPdfData {
  const ReceiptPdfData({
    required this.receiptNumber,
    required this.schoolName,
    required this.title,
    required this.dateLabel,
    required this.paymentMethod,
    required this.statusLabel,
    required this.studentName,
    required this.classLabel,
    required this.lineItems,
    required this.totalAmount,
    this.copyLabel = 'ORIGINAL',
    this.signatoryName = 'Authorised Signatory',
    this.financeReceipt,
  });

  final String receiptNumber;
  final String schoolName;
  final String title;
  final String dateLabel;
  final String paymentMethod;
  final String statusLabel;
  final String studentName;
  final String classLabel;
  final List<ReceiptPdfLineItem> lineItems;
  final int totalAmount;

  /// ORIGINAL / DUPLICATE / COPY — stamped top-right (FIN-3 / FIN-4).
  final String copyLabel;
  final String signatoryName;
  final FinanceReceiptDetail? financeReceipt;
}

class FinanceReceiptPdfService {
  const FinanceReceiptPdfService();

  Future<Uint8List> buildReceiptPdf({
    required String receiptNumber,
    required String schoolName,
    required String title,
    required String dateLabel,
    required String paymentMethod,
    required String statusLabel,
    required String studentName,
    required String classLabel,
    required List<ReceiptPdfLineItem> lineItems,
    required int totalAmount,
    String copyLabel = 'ORIGINAL',
    String signatoryName = 'Authorised Signatory',
    FinanceReceiptDetail? financeReceipt,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AksharaSpacing.s6),
        build: (context) => _receiptPage(
          ReceiptPdfData(
            receiptNumber: receiptNumber,
            schoolName: schoolName,
            title: title,
            dateLabel: dateLabel,
            paymentMethod: paymentMethod,
            statusLabel: statusLabel,
            studentName: studentName,
            classLabel: classLabel,
            lineItems: lineItems,
            totalAmount: totalAmount,
            copyLabel: copyLabel,
            signatoryName: signatoryName,
            financeReceipt: financeReceipt,
          ),
        ),
      ),
    );
    return document.save();
  }

  /// FIN-5: batch receipt printing — one receipt per page in a single document
  /// ("print today's receipts"). Reuses the exact single-receipt layout.
  Future<Uint8List> buildBatchReceiptsPdf(List<ReceiptPdfData> receipts) async {
    final document = pw.Document();
    for (final receipt in receipts) {
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(AksharaSpacing.s6),
          build: (context) => _receiptPage(receipt),
        ),
      );
    }
    return document.save();
  }

  /// The shared receipt body — letterhead (logo placeholder + school name),
  /// ORIGINAL/DUPLICATE stamp, details, line items, total + amount-in-words
  /// (FIN-3), and an authorised-signatory line.
  List<pw.Widget> _receiptPage(ReceiptPdfData r) {
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
                  r.schoolName,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(r.title, style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
          ),
          _copyStamp(r.copyLabel),
        ],
      ),
      pw.Divider(),
      _kv('Receipt number', r.receiptNumber),
      _kv('Date', r.dateLabel),
      _kv('Payment method', r.paymentMethod),
      _kv('Status', r.statusLabel),
      _kv('Student', r.studentName),
      _kv('Class', r.classLabel),
      if (r.financeReceipt != null) ...[
        _kv('Collection ID', r.financeReceipt!.collectionId),
        _kv(
          'Invoice ID',
          r.financeReceipt!.invoiceId.isEmpty ? 'N/A' : r.financeReceipt!.invoiceId,
        ),
      ],
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: const ['Line item', 'Amount'],
        data: [
          for (final line in r.lineItems) [line.label, _formatInr(line.amount)],
        ],
        border: pw.TableBorder.all(color: PdfColors.grey400),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        cellAlignment: pw.Alignment.centerLeft,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      ),
      pw.SizedBox(height: 10),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Total Paid: ${_formatInr(r.totalAmount)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        '(${rupeesInWords(r.totalAmount)})',
        style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
      ),
      pw.SizedBox(height: 40),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(width: 160, child: pw.Divider(color: PdfColors.grey600)),
              pw.Text(r.signatoryName, style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'This is a computer-generated receipt.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    ];
  }

  pw.Widget _logoPlaceholder() => pw.Container(
        width: 60,
        height: 60,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
        alignment: pw.Alignment.center,
        child: pw.Text('LOGO',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      );

  pw.Widget _copyStamp(String label) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(
          label,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700),
        ),
      );

  Future<void> printReceipt(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareReceipt({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  pw.Widget _kv(String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: AksharaSpacing.s1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
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

  /// Indian-format money for the receipt (FIN-3) — Lakh/Crore grouping via the
  /// shared [indianDigitGroups] helper, consistent with the amount-in-words
  /// line. "INR " prefix (not "₹") because the bundled PDF font lacks the rupee
  /// glyph.
  String _formatInr(int amount) =>
      '${amount < 0 ? '-INR ' : 'INR '}${indianDigitGroups(amount.abs())}';
}

class ReceiptPdfLineItem {
  const ReceiptPdfLineItem({required this.label, required this.amount});

  final String label;
  final int amount;
}
