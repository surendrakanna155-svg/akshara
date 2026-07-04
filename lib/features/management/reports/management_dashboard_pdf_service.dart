import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../management_models.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../theme/spacing.dart';

class ManagementDashboardPdfService {
  const ManagementDashboardPdfService();

  Future<Uint8List> buildDashboardPdf({
    required String schoolName,
    required String periodLabel,
    required ManagementDashboardData data,
  }) async {
    // XCT-1: both tables ride the ONE shared grid primitive (consistent
    // border/header/cell styling with every other module export).
    const export = AksharaReportExportService();
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AksharaSpacing.s6),
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
          export.buildGridTable(
            headers: const ['Metric', 'Value', 'Detail'],
            rows: [
              for (final kpi in data.kpis)
                [
                  kpi.label,
                  kpi.value,
                  kpi.detail?.isNotEmpty == true ? kpi.detail! : '-',
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Approval queue (top ${data.approvalQueue.length})',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          export.buildGridTable(
            headers: const ['Title', 'Requester', 'Amount', 'Status'],
            rows: [
              for (final item in data.approvalQueue)
                [item.title, item.requester, item.amount, item.status.name],
            ],
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
      padding: const pw.EdgeInsets.only(bottom: AksharaSpacing.s1),
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
