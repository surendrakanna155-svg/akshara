import '../../../core/reports/akshara_report_export_service.dart';
import '../sis_models.dart';

/// Presentation label for a SIS student lifecycle status (exports + rows).
String sisStudentStatusLabel(SisStudentStatus status) => switch (status) {
      SisStudentStatus.active => 'Active',
      SisStudentStatus.prospect => 'Prospect',
      SisStudentStatus.transferred => 'Transferred',
      SisStudentStatus.exited => 'Exited',
      SisStudentStatus.alumni => 'Alumni',
    };

/// Turns SIS view-models into the shared XCT-1 grid shape (headers + string
/// rows) and drives CSV / PDF exports through [AksharaReportExportService].
/// Mirrors the HR exporter template — no SIS report invents its own layout.
class SisReportExporters {
  const SisReportExporters(this._service);

  final AksharaReportExportService _service;

  /// ISO date part of an exit timestamp (readable in a grid cell).
  static String _dateOnly(String value) =>
      value.length >= 10 && value[4] == '-' ? value.substring(0, 10) : value;

  // --- SIS-2 student registry --------------------------------------------------

  static const List<String> registryHeaders = [
    'Admission #',
    'Public ID',
    'Name',
    'Class',
    'Section',
    'Status',
    'Parent name',
    'Parent phone',
  ];

  static List<List<String>> registryRows(List<SisStudent> students) {
    return [
      for (final student in students)
        [
          student.admissionNumber,
          _psid(student.publicStudentId),
          student.studentName,
          student.classLabel,
          student.section,
          sisStudentStatusLabel(student.status),
          student.guardianName,
          student.phone,
        ],
    ];
  }

  /// Public Student ID for a grid cell; "—" when the school has no code.
  static String _psid(String? publicStudentId) =>
      (publicStudentId == null || publicStudentId.trim().isEmpty)
          ? '—'
          : publicStudentId.trim();

  Future<void> shareRegistryCsv(List<SisStudent> students) {
    return _service.shareGridCsv(
      filename: 'sis_registry',
      headers: registryHeaders,
      rows: registryRows(students),
    );
  }

  Future<void> shareRegistryPdf(List<SisStudent> students) {
    return _service.shareGridPdf(
      filename: 'sis_registry',
      reportTitle: 'SIS Student Registry',
      moduleLabel: 'SIS · Student Registry',
      headers: registryHeaders,
      rows: registryRows(students),
      generatedAtLabel: DateTime.now().toIso8601String(),
    );
  }

  // --- SIS-2 class list (compact per-class roster) -----------------------------

  static const List<String> classListHeaders = [
    'Admission #',
    'Name',
    'Class',
    'Section',
    'Status',
  ];

  static List<List<String>> classListRows(List<SisStudent> students) {
    return [
      for (final student in students)
        [
          student.admissionNumber,
          student.studentName,
          student.classLabel,
          student.section,
          sisStudentStatusLabel(student.status),
        ],
    ];
  }

  Future<void> shareClassListCsv(List<SisStudent> students) {
    return _service.shareGridCsv(
      filename: 'sis_class_list',
      headers: classListHeaders,
      rows: classListRows(students),
    );
  }

  Future<void> shareClassListPdf(List<SisStudent> students) {
    return _service.shareGridPdf(
      filename: 'sis_class_list',
      reportTitle: 'Class list',
      moduleLabel: 'SIS · Class List',
      headers: classListHeaders,
      rows: classListRows(students),
      generatedAtLabel: DateTime.now().toIso8601String(),
    );
  }

  // --- SIS-2 parent contact sheet (student → guardian contact) ------------------

  static const List<String> contactSheetHeaders = [
    'Name',
    'Class',
    'Section',
    'Parent name',
    'Parent phone',
  ];

  static List<List<String>> contactSheetRows(List<SisStudent> students) {
    return [
      for (final student in students)
        [
          student.studentName,
          student.classLabel,
          student.section,
          student.guardianName,
          student.phone,
        ],
    ];
  }

  Future<void> shareContactSheetCsv(List<SisStudent> students) {
    return _service.shareGridCsv(
      filename: 'sis_contact_sheet',
      headers: contactSheetHeaders,
      rows: contactSheetRows(students),
    );
  }

  Future<void> shareContactSheetPdf(List<SisStudent> students) {
    return _service.shareGridPdf(
      filename: 'sis_contact_sheet',
      reportTitle: 'Parent contact sheet',
      moduleLabel: 'SIS · Parent Contact Sheet',
      headers: contactSheetHeaders,
      rows: contactSheetRows(students),
      generatedAtLabel: DateTime.now().toIso8601String(),
    );
  }

  // --- SIS-5 transfers / exit log ----------------------------------------------

  static const List<String> transfersHeaders = [
    'Student',
    'Admission #',
    'Class',
    'Section',
    'Academic year',
    'Status',
    'Exited at',
    'Reason',
  ];

  static List<List<String>> transfersRows(List<SisTransferRecord> records) {
    return [
      for (final record in records)
        [
          record.studentName,
          record.admissionNumber,
          record.classLabel,
          record.section,
          record.academicYear,
          sisStudentStatusLabel(record.status),
          _dateOnly(record.exitedAt),
          record.reason ?? '',
        ],
    ];
  }

  Future<void> shareTransfersCsv(List<SisTransferRecord> records) {
    return _service.shareGridCsv(
      filename: 'sis_transfers_exit_log',
      headers: transfersHeaders,
      rows: transfersRows(records),
    );
  }

  Future<void> shareTransfersPdf(List<SisTransferRecord> records) {
    return _service.shareGridPdf(
      filename: 'sis_transfers_exit_log',
      reportTitle: 'Transfers & Exit Log',
      moduleLabel: 'SIS · Transfers & Exits',
      headers: transfersHeaders,
      rows: transfersRows(records),
      generatedAtLabel: DateTime.now().toIso8601String(),
    );
  }
}
