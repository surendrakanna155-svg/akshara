import '../../../core/reports/akshara_report_export_service.dart';
import '../director_models.dart';

/// DIR-3 — turns the Director portfolio view-models into the shared XCT-1 grid
/// shape (headers + string rows) and drives CSV / PDF exports through
/// [AksharaReportExportService]. Every export rides the same grid primitive
/// (shareGridCsv / shareGridPdf) — no report invents its own CSV/PDF layout.
/// Aggregated, school-level figures only (no student/parent PII).
class DirectorReportExporters {
  const DirectorReportExporters(this._service);

  final AksharaReportExportService _service;

  static String _money(int inr) => inr.toString();

  // --- DIR-1 school comparison / league table --------------------------------

  static const List<String> schoolComparisonHeaders = [
    'Rank',
    'School',
    'Location',
    'Students',
    'Revenue (Cr)',
    'Admissions QTD',
    'Fee %',
    'Outstanding (₹)',
    'Health',
    'Status',
  ];

  /// [schools] must already be in the display (sorted/ranked) order — the CSV/PDF
  /// mirrors exactly what the director sees on screen. Rank is 1-based row order.
  static List<List<String>> schoolComparisonRows(List<DirectorSchoolRow> schools) {
    return [
      for (var i = 0; i < schools.length; i++)
        [
          '${i + 1}',
          schools[i].schoolName,
          schools[i].location,
          '${schools[i].students}',
          schools[i].revenueCr.toStringAsFixed(1),
          '${schools[i].admissionsQtd}',
          '${schools[i].feeCollectionPercent}',
          _money(schools[i].outstandingInr),
          '${schools[i].healthScore}',
          _statusLabel(schools[i].status),
        ],
    ];
  }

  Future<void> shareSchoolComparisonCsv(List<DirectorSchoolRow> schools) {
    return _service.shareGridCsv(
      filename: 'director_school_comparison',
      headers: schoolComparisonHeaders,
      rows: schoolComparisonRows(schools),
    );
  }

  Future<void> shareSchoolComparisonPdf(List<DirectorSchoolRow> schools) {
    return _service.shareGridPdf(
      filename: 'director_school_comparison',
      reportTitle: 'Multi-school comparison',
      moduleLabel: 'Director · Portfolio · Aggregated data only · No student PII',
      headers: schoolComparisonHeaders,
      rows: schoolComparisonRows(schools),
      generatedAtLabel: DateTime.now().toIso8601String(),
      // Students onward are numeric/amount columns → right-aligned.
      rightAlignFrom: 3,
    );
  }

  // --- DIR-2 consolidated collection report ----------------------------------

  static const List<String> collectionHeaders = [
    'School',
    'Fee %',
    'Billed (₹)',
    'Collected (₹)',
    'Outstanding (₹)',
  ];

  /// Per-school rows followed by an org TOTAL row (matches the on-screen report).
  static List<List<String>> collectionRows(DirectorCollectionReport report) {
    return [
      for (final r in report.schools)
        [
          r.name,
          '${r.feeCollectionPercent}',
          _money(r.billedInr),
          _money(r.collectedInr),
          _money(r.outstandingInr),
        ],
      [
        'TOTAL',
        '${report.totals.feeCollectionPercent}',
        _money(report.totals.billedInr),
        _money(report.totals.collectedInr),
        _money(report.totals.outstandingInr),
      ],
    ];
  }

  Future<void> shareCollectionCsv(DirectorCollectionReport report) {
    return _service.shareGridCsv(
      filename: 'director_collection_report',
      headers: collectionHeaders,
      rows: collectionRows(report),
    );
  }

  Future<void> shareCollectionPdf(DirectorCollectionReport report) {
    return _service.shareGridPdf(
      filename: 'director_collection_report',
      reportTitle: 'Consolidated collection report',
      moduleLabel: 'Director · Collections · Aggregated data only · No student PII',
      headers: collectionHeaders,
      rows: collectionRows(report),
      generatedAtLabel: DateTime.now().toIso8601String(),
      rightAlignFrom: 1,
    );
  }

  static String _statusLabel(DirectorSchoolStatus status) => switch (status) {
        DirectorSchoolStatus.topPerformer => 'Top Performer',
        DirectorSchoolStatus.onTrack => 'On Track',
        DirectorSchoolStatus.atRisk => 'At Risk',
        DirectorSchoolStatus.critical => 'Critical',
      };
}
