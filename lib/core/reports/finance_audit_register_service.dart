import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../audit/audit_event.dart';
import '../audit/audit_provider.dart';
import 'akshara_report_export_service.dart';
import '../../theme/spacing.dart';

/// Generates a finance audit register from local audit events (Phase E).
class FinanceAuditRegisterService {
  const FinanceAuditRegisterService();

  static const _financeTypes = <AuditEventType>{
    AuditEventType.paymentInitiated,
    AuditEventType.paymentCaptured,
    AuditEventType.refundApproved,
    AuditEventType.refundRejected,
    AuditEventType.collectionCreated,
    AuditEventType.collectionCancelled,
    AuditEventType.invoiceIssued,
    AuditEventType.invoiceCancelled,
    AuditEventType.feeStructureCreated,
    AuditEventType.feeStructureUpdated,
    AuditEventType.feeStructureArchived,
    AuditEventType.feeAssignmentCreated,
    AuditEventType.feeAssignmentCancelled,
    AuditEventType.financeHandoffSent,
    AuditEventType.receiptPdfExported,
  };

  List<AuditEvent> filterFinanceEvents(List<AuditEvent> events) {
    return events
        .where(
          (event) =>
              event.metadata['module'] == 'finance' ||
              _financeTypes.contains(event.type),
        )
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<Uint8List> buildRegisterPdf({
    required List<AuditEvent> events,
    String? generatedAtLabel,
  }) async {
    final financeEvents = filterFinanceEvents(events);
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(AksharaSpacing.s6),
        build: (context) => [
          pw.Text(
            'Finance Audit Register',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          if (generatedAtLabel != null) ...[
            pw.SizedBox(height: 4),
            pw.Text('Generated: $generatedAtLabel'),
          ],
          pw.SizedBox(height: 4),
          pw.Text('Entries: ${financeEvents.length}'),
          pw.SizedBox(height: 16),
          if (financeEvents.isEmpty)
            pw.Text('No finance audit events recorded yet.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Timestamp', 'Type', 'User', 'Entity', 'Action'],
              data: [
                for (final event in financeEvents)
                  [
                    event.timestamp.toIso8601String(),
                    event.type.name,
                    event.userId ?? '—',
                    event.metadata['entityId'] ?? '—',
                    event.metadata['action'] ?? '—',
                  ],
              ],
              border: pw.TableBorder.all(color: PdfColors.grey400),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
            ),
        ],
      ),
    );
    return document.save();
  }

  String buildRegisterCsv({required List<AuditEvent> events}) {
    final financeEvents = filterFinanceEvents(events);
    final export = const AksharaReportExportService();
    return export.buildTabularReportCsv(
      reportTitle: 'Finance Audit Register',
      rows: [
        for (final event in financeEvents)
          MapEntry(
            '${event.timestamp.toIso8601String()} · ${event.type.name}',
            '${event.metadata['action'] ?? '—'} · ${event.metadata['entityId'] ?? '—'}',
          ),
      ],
    );
  }
}

final financeAuditRegisterServiceProvider =
    Provider<FinanceAuditRegisterService>(
  (ref) => const FinanceAuditRegisterService(),
);

final financeAuditRegisterEventsProvider =
    FutureProvider<List<AuditEvent>>((ref) async {
  final events = await ref.watch(auditEventsProvider.future);
  return ref.read(financeAuditRegisterServiceProvider).filterFinanceEvents(events);
});
