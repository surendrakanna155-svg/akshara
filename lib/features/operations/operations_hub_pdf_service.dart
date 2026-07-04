import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/reports/akshara_report_export_service.dart';
import '../../theme/spacing.dart';
import '../phase5/phase5_models.dart';

/// PRI-3 — composes the Operations Hub snapshot into a "Daily school report"
/// PDF for print / share. Mirrors [ManagementDashboardPdfService].
class OperationsHubPdfService {
  const OperationsHubPdfService();

  Future<Uint8List> buildDailyReportPdf({
    required String schoolName,
    required String dateLabel,
    required OperationsHubSnapshot snapshot,
  }) async {
    // XCT-1: every table rides the ONE shared grid primitive.
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
            'Daily School Report',
            style: const pw.TextStyle(fontSize: 14),
          ),
          _kv('Date', dateLabel),
          _kv('School health', '${snapshot.schoolHealth}/100'),
          pw.SizedBox(height: 10),
          pw.Text(
            'Daily summary',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          export.buildGridTable(
            headers: const ['Metric', 'Value'],
            rows: [
              ['Attendance', '${snapshot.dailySummary.attendancePct}%'],
              [
                'Collections today',
                '₹${snapshot.dailySummary.collectionsToday.toStringAsFixed(0)}',
              ],
              [
                'Communications',
                '${snapshot.dailySummary.communicationsToday}',
              ],
              ['Critical alerts', '${snapshot.dailySummary.criticalAlerts}'],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Critical alerts (${snapshot.criticalAlerts.length})',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (snapshot.criticalAlerts.isEmpty)
            pw.Text('No critical alerts today.')
          else
            export.buildGridTable(
              headers: const ['Title', 'Module', 'Severity'],
              rows: [
                for (final alert in snapshot.criticalAlerts)
                  [alert.title, alert.module, alert.severity],
              ],
            ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Pending actions (${snapshot.pendingActions.length})',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (snapshot.pendingActions.isEmpty)
            pw.Text('No pending actions.')
          else
            export.buildGridTable(
              headers: const ['Title', 'Module'],
              rows: [
                for (final action in snapshot.pendingActions)
                  [action.title, action.module],
              ],
            ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Risk widgets',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          export.buildGridTable(
            headers: const ['Widget', 'Count'],
            rows: [
              ['Student risk alerts', '${snapshot.widgets.studentRiskAlerts}'],
              [
                'Employee risk alerts',
                '${snapshot.widgets.employeeRiskAlerts}',
              ],
              ['Inventory alerts', '${snapshot.widgets.inventoryAlerts}'],
              ['Fee alerts', '${snapshot.widgets.feeAlerts}'],
            ],
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<void> printDailyReport(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareDailyReport({
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
