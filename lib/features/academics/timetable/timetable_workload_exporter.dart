import '../../../core/reports/akshara_report_export_service.dart';
import 'timetable_models.dart';

/// Roadmap gap #9 — turns the unified workload rollup into the shared XCT-1 grid
/// shape (headers + string rows) and drives CSV / PDF exports through
/// [AksharaReportExportService]. No bespoke CSV/PDF layout — it rides the same
/// grid primitive every other Akshara report uses.
class TimetableWorkloadExporter {
  const TimetableWorkloadExporter(this._service);

  final AksharaReportExportService _service;

  static const List<String> headers = [
    'Teacher',
    'Periods/week',
    'Status',
    'Sections',
    'Subjects',
  ];

  static String statusLabel(TeacherWorkloadStatus status) => switch (status) {
        TeacherWorkloadStatus.over => 'Overloaded',
        TeacherWorkloadStatus.under => 'Under-utilised',
        TeacherWorkloadStatus.balanced => 'Balanced',
      };

  static List<List<String>> rows(WorkloadRollup rollup) {
    return [
      for (final t in rollup.teachers)
        [
          t.teacherName,
          '${t.periodCount}',
          statusLabel(t.status),
          '${t.sections.length}',
          t.subjectIds.join(', '),
        ],
    ];
  }

  Future<void> shareCsv(WorkloadRollup rollup) {
    return _service.shareGridCsv(
      filename: 'teacher_workload',
      headers: headers,
      rows: rows(rollup),
    );
  }

  Future<void> sharePdf(WorkloadRollup rollup) {
    final s = rollup.summary;
    return _service.shareGridPdf(
      filename: 'teacher_workload',
      reportTitle: 'Teacher workload',
      moduleLabel:
          'Timetable · ${s.totalTeachers} teachers · ${s.overloaded} over · '
          '${s.underloaded} under · ${s.balanced} balanced · avg ${s.avgPeriods}',
      headers: headers,
      rows: rows(rollup),
      generatedAtLabel: DateTime.now().toIso8601String(),
      rightAlignFrom: 1,
    );
  }
}
