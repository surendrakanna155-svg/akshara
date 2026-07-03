import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../receipts/receipt_models.dart';

/// PAR-4 — builds a parent "year fee statement" (CSV + PDF) from the child's
/// receipts. Reuses the shared XCT-1 grid exporter (one header row + one row
/// per receipt) so the statement rides the same battle-tested primitive as
/// every other module report — no bespoke CSV/PDF assembly here.
class ParentYearStatementExporter {
  const ParentYearStatementExporter(this._export);

  final AksharaReportExportService _export;

  static const List<String> headers = <String>[
    'Receipt No',
    'Date',
    'Description',
    'Method',
    'Status',
    'Amount (INR)',
  ];

  /// The statement grid rows (public for tests / deterministic assertions).
  List<List<String>> rows(List<FeeReceipt> receipts) {
    return [
      for (final r in receipts)
        [
          r.receiptNumber,
          r.dateLabel,
          r.title,
          r.paymentMethod,
          r.statusLabel,
          r.amount.toString(),
        ],
      // Total row (numeric column right-aligned in PDF).
      ['', '', '', '', 'Total', _total(receipts).toString()],
    ];
  }

  int _total(List<FeeReceipt> receipts) =>
      receipts.fold<int>(0, (sum, r) => sum + r.amount);

  String _fileName(String childName) {
    final safe = childName.trim().isEmpty
        ? 'child'
        : childName.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return 'fee_statement_$safe';
  }

  Future<void> shareCsv({
    required List<FeeReceipt> receipts,
    required String childName,
  }) {
    return _export.shareGridCsv(
      filename: _fileName(childName),
      headers: headers,
      rows: rows(receipts),
    );
  }

  Future<void> sharePdf({
    required List<FeeReceipt> receipts,
    required String childName,
    String? generatedAtLabel,
  }) {
    return _export.shareGridPdf(
      filename: _fileName(childName),
      reportTitle: 'Fee Statement',
      moduleLabel: childName.trim().isEmpty ? 'Fees' : '$childName · Fees',
      headers: headers,
      rows: rows(receipts),
      generatedAtLabel: generatedAtLabel,
      rightAlignFrom: 5,
    );
  }
}

final parentYearStatementExporterProvider =
    Provider<ParentYearStatementExporter>(
  (ref) => ParentYearStatementExporter(
    ref.read(aksharaReportExportServiceProvider),
  ),
);
