import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../management_models.dart';

class ManagementDashboardPdfService {
  const ManagementDashboardPdfService();

  Future<Uint8List> buildDashboardPdf({
    required String schoolName,
    required String periodLabel,
    required ManagementDashboardData data,
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
          pw.Text(
            'Management Dashboard Export',
            style: const pw.TextStyle(fontSize: 14),
          ),
          _kv('Period', periodLabel),
          _kv('AI insight', data.aiInsight),
          pw.SizedBox(height: 10),
          pw.Text(
            'KPIs',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Metric', 'Value', 'Detail'],
            data: [
              for (final kpi in data.kpis)
                [
                  kpi.label,
                  kpi.value,
                  kpi.detail?.isNotEmpty == true ? kpi.detail! : '-',
                ],
            ],
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Approval queue (top ${data.approvalQueue.length})',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Title', 'Requester', 'Amount', 'Status'],
            data: [
              for (final item in data.approvalQueue)
                [item.title, item.requester, item.amount, item.status.name],
            ],
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<void> printDashboard(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareDashboard({
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
            width: 100,
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
