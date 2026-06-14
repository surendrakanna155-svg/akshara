import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../finance_models.dart';

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
    FinanceReceiptDetail? financeReceipt,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            schoolName,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Fee Receipt', style: const pw.TextStyle(fontSize: 14)),
          pw.Divider(),
          _kv('Receipt number', receiptNumber),
          _kv('Title', title),
          _kv('Date', dateLabel),
          _kv('Payment method', paymentMethod),
          _kv('Status', statusLabel),
          _kv('Student', studentName),
          _kv('Class', classLabel),
          if (financeReceipt != null) ...[
            _kv('Collection ID', financeReceipt.collectionId),
            _kv('Invoice ID', financeReceipt.invoiceId.isEmpty ? 'N/A' : financeReceipt.invoiceId),
          ],
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Line item', 'Amount'],
            data: [
              for (final line in lineItems)
                [line.label, _formatInr(line.amount)],
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
              'Total Paid: ${_formatInr(totalAmount)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
    return document.save();
  }

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
      padding: const pw.EdgeInsets.only(bottom: 4),
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

class ReceiptPdfLineItem {
  const ReceiptPdfLineItem({required this.label, required this.amount});

  final String label;
  final int amount;
}
