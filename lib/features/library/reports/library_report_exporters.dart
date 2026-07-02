import '../../../core/reports/akshara_report_export_service.dart';
import '../library_models.dart';

/// LIB-1 — turns the overdue-loans list into the shared XCT-1 grid shape
/// (headers + string rows) and drives CSV / PDF exports through
/// [AksharaReportExportService]. Rides the same grid primitive as every other
/// module report — no bespoke CSV/PDF layout.
class LibraryReportExporters {
  const LibraryReportExporters(this._service);

  final AksharaReportExportService _service;

  static String _memberType(LibraryMemberType type) => switch (type) {
        LibraryMemberType.student => 'Student',
        LibraryMemberType.teacher => 'Teacher',
        LibraryMemberType.staff => 'Staff',
      };

  static const List<String> overdueHeaders = [
    'Member',
    'Type',
    'Book',
    'ISBN',
    'Due date',
    'Days overdue',
    'Accrued fine',
  ];

  static List<List<String>> overdueRows(List<OverdueLoan> loans) {
    return [
      for (final loan in loans)
        [
          loan.memberName,
          _memberType(loan.memberType),
          loan.bookTitle,
          loan.isbn,
          loan.dueDate,
          '${loan.daysOverdue}',
          loan.accruedFine,
        ],
    ];
  }

  Future<void> shareOverdueCsv(List<OverdueLoan> loans) {
    return _service.shareGridCsv(
      filename: 'library_overdue_loans',
      headers: overdueHeaders,
      rows: overdueRows(loans),
    );
  }

  Future<void> shareOverduePdf(List<OverdueLoan> loans) {
    return _service.shareGridPdf(
      filename: 'library_overdue_loans',
      reportTitle: 'Overdue loans',
      moduleLabel: 'Library · Circulation',
      headers: overdueHeaders,
      rows: overdueRows(loans),
      generatedAtLabel: DateTime.now().toIso8601String(),
      rightAlignFrom: 5,
    );
  }
}
