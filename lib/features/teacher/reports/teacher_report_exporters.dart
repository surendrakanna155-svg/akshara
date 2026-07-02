import '../../../core/reports/akshara_report_export_service.dart';
import '../attendance/attendance_models.dart';
import '../timetable/timetable_models.dart';

/// TCH-3 / TCH-7 — turns teacher view-models into the shared XCT-1 grid shape
/// (headers + string rows) and drives CSV / PDF exports through
/// [AksharaReportExportService]. Mirrors the HR exporter template so every
/// teacher report rides the same grid primitive — no report invents its own
/// CSV/PDF layout.
class TeacherReportExporters {
  const TeacherReportExporters(this._service);

  final AksharaReportExportService _service;

  // --- TCH-3 attendance register --------------------------------------------

  static const List<String> attendanceRegisterHeaders = [
    'Roll',
    'Student',
    'Status',
  ];

  static List<List<String>> attendanceRegisterRows(TeacherAttendanceData data) {
    final rows = <List<String>>[
      for (final s in _byRoll(data.students))
        [s.rollNo, s.name, s.mark.label],
    ];
    // Summary tail (present / absent / late / half-day / excused).
    rows.add(const ['', '', '']);
    rows.add(['SUMMARY', 'Present', '${data.presentCount}']);
    rows.add(['', 'Absent', '${data.absentCount}']);
    rows.add(['', 'Late', '${data.lateCount}']);
    rows.add(['', 'Half-day', '${data.halfDayCount}']);
    rows.add(['', 'Excused', '${data.excusedCount}']);
    return rows;
  }

  static List<TeacherAttendanceStudent> _byRoll(
    List<TeacherAttendanceStudent> students,
  ) {
    final sorted = [...students]
      ..sort((a, b) => a.rollNo.compareTo(b.rollNo));
    return sorted;
  }

  static String _classLabelFor(TeacherAttendanceData data) {
    for (final c in data.classes) {
      if (c.id == data.selectedClassId) return c.label;
    }
    return data.selectedClassId;
  }

  static String _fileSlug(String value) =>
      value.trim().isEmpty ? 'class' : value.trim().replaceAll(RegExp(r'\s+'), '_');

  Future<void> shareAttendanceRegisterCsv(TeacherAttendanceData data) {
    final label = _classLabelFor(data);
    return _service.shareGridCsv(
      filename: 'attendance_register_${_fileSlug(label)}',
      headers: attendanceRegisterHeaders,
      rows: attendanceRegisterRows(data),
    );
  }

  Future<void> shareAttendanceRegisterPdf(TeacherAttendanceData data) {
    final label = _classLabelFor(data);
    return _service.shareGridPdf(
      filename: 'attendance_register_${_fileSlug(label)}',
      reportTitle: 'Class attendance register',
      moduleLabel: 'Teacher · Attendance · $label',
      headers: attendanceRegisterHeaders,
      rows: attendanceRegisterRows(data),
      generatedAtLabel: DateTime.now().toIso8601String(),
    );
  }

  // --- TCH-7 weekly timetable ------------------------------------------------

  static const List<String> timetableHeaders = [
    'Day',
    'Period',
    'Time',
    'Subject',
    'Class',
    'Room',
  ];

  static List<List<String>> timetableRows(TeacherTimetableData data) {
    return [
      for (final day in data.days)
        for (final p in day.periods)
          [
            day.fullLabel,
            p.periodLabel,
            p.timeRange,
            p.subject,
            p.classLabel,
            p.roomLabel,
          ],
    ];
  }

  Future<void> shareTimetableCsv(TeacherTimetableData data) {
    return _service.shareGridCsv(
      filename: 'weekly_timetable',
      headers: timetableHeaders,
      rows: timetableRows(data),
    );
  }

  Future<void> shareTimetablePdf(TeacherTimetableData data) {
    return _service.shareGridPdf(
      filename: 'weekly_timetable',
      reportTitle: 'Weekly timetable',
      moduleLabel: 'Teacher · Timetable · ${data.weekRangeLabel}',
      headers: timetableHeaders,
      rows: timetableRows(data),
      generatedAtLabel: DateTime.now().toIso8601String(),
    );
  }
}
