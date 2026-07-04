import '../../../../exams/exam_administration_requests.dart';
import '../../../../exams/exam_administration_store.dart';
import '../../../../exams/exam_reports.dart';
import '../../education/mapper/education_mapper.dart';

/// Maps exam administration API payloads to domain models.
class ExamMapper {
  const ExamMapper();

  ExamSession toSession(Map<String, dynamic> json) {
    return ExamSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
      section: json['section'] as String? ?? json['sectionName'] as String? ?? '',
      termLabel: json['termLabel'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      timeLabel: json['timeLabel'] as String? ?? '',
      venueLabel: json['venueLabel'] as String? ?? '',
      syllabusLabel: json['syllabusLabel'] as String? ?? '',
      maxMarks: (json['maxMarks'] as num?)?.toInt() ?? 100,
      phase: _phaseFromApi(json['phase'] as String? ?? 'draft'),
      examType: EducationMapper.examTypeFromApi(
        json['examType'] as String? ?? 'unit_test',
      ),
      coordinatorVerified: json['coordinatorVerified'] as bool? ?? false,
      rejectionComment: json['rejectionComment'] as String?,
      marksEntryDeadline: _parseDate(
        json['marksEntryDeadline'] ?? json['marks_entry_deadline'],
      ),
    );
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  List<ExamSession> toSessions(List<dynamic> items) =>
      items.map((item) => toSession(item as Map<String, dynamic>)).toList();

  ExamMarkRecord toMark(Map<String, dynamic> json) {
    final marksRaw = json['marksObtained'] ?? json['marks_obtained'];
    final status = ExamMarkStatus.fromWire(
      json['status'] as String? ?? json['attendance_status'] as String?,
    );
    final versionRaw = json['rowVersion'] ?? json['row_version'];
    return ExamMarkRecord(
      id: json['id'] as String,
      examId: json['examId'] as String? ?? '',
      sisStudentId: json['sisStudentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      rollNo: json['rollNo'] as String? ?? json['roll_number'] as String? ?? '',
      // A non-present student has null marks regardless of any payload value.
      marksObtained: !status.isPresent
          ? null
          : (marksRaw == null ? null : (marksRaw as num).toInt()),
      published: json['published'] as bool? ?? false,
      status: status,
      // REL-5 — carry the read version so the next edit sends it as
      // `expectedVersion` (first-write optimistic concurrency).
      rowVersion: versionRaw is num ? versionRaw.toInt() : null,
    );
  }

  List<ExamMarkRecord> toMarks(List<dynamic> items) =>
      items.map((item) => toMark(item as Map<String, dynamic>)).toList();

  /// EXM-1 — request body for the bulk marks save. Non-present entries send
  /// null marks (the server forces null too).
  Map<String, dynamic> bulkMarksBody(BulkUpdateExamMarksRequest request) {
    return {
      'entries': [
        for (final entry in request.entries)
          {
            'id': entry.markEntryId,
            'marksObtained':
                entry.status.isPresent ? entry.marksObtained : null,
            'status': entry.status.wire,
          },
      ],
    };
  }

  /// EXM-1 — parse the { updated: [...], failed: [{ id, reason }] } response.
  BulkExamMarkSaveResult toBulkResult(Map<String, dynamic> data) {
    final updatedRaw = data['updated'];
    final failedRaw = data['failed'];
    return BulkExamMarkSaveResult(
      updated: [
        if (updatedRaw is List)
          for (final raw in updatedRaw)
            if (raw is Map) toMark(Map<String, dynamic>.from(raw)),
      ],
      failed: [
        if (failedRaw is List)
          for (final raw in failedRaw)
            if (raw is Map)
              BulkExamMarkFailure(
                markEntryId: (raw['id'] ?? '').toString(),
                reason: (raw['reason'] ?? '').toString(),
              ),
      ],
    );
  }

  /// EXM-2 — parse one marks-entry progress row.
  MarksEntryProgress toProgress(Map<String, dynamic> json) {
    return MarksEntryProgress(
      examId: json['examId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
      sectionName:
          json['sectionName'] as String? ?? json['section'] as String? ?? '',
      enteredCount: (json['enteredCount'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      marksEntryDeadline: _parseDate(
        json['marksEntryDeadline'] ?? json['marks_entry_deadline'],
      ),
    );
  }

  List<MarksEntryProgress> toProgressList(List<dynamic> items) => items
      .map((item) => toProgress(item as Map<String, dynamic>))
      .toList();

  PublishedExamResult toPublishedResult(Map<String, dynamic> json) {
    return PublishedExamResult(
      markEntryId: json['markEntryId'] as String? ?? json['id'] as String? ?? '',
      sisStudentId: json['sisStudentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      examId: json['examId'] as String? ?? '',
      examTitle: json['examTitle'] as String? ?? '',
      termLabel: json['termLabel'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      // Non-present marks arrive as null; store 0 (the row is excluded from stats
      // by status, and rendered via the display code).
      scoreObtained: (json['scoreObtained'] as num?)?.toInt() ?? 0,
      maxScore: (json['maxScore'] as num?)?.toInt() ?? 100,
      grade: json['grade'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      status: ExamMarkStatus.fromWire(json['status'] as String?),
    );
  }

  List<PublishedExamResult> toPublishedResults(List<dynamic> items) => items
      .map((item) => toPublishedResult(item as Map<String, dynamic>))
      .toList();

  Map<String, dynamic> createExamBody(CreateExamAdministrationRequest request) {
    return {
      'title': request.title,
      'subject': request.subject,
      'grade': request.grade,
      'section': request.section,
      'termLabel': request.termLabel,
      'dateLabel': request.dateLabel,
      'timeLabel': request.timeLabel,
      'venueLabel': request.venueLabel,
      'syllabusLabel': request.syllabusLabel,
      'maxMarks': request.maxMarks,
      'examType': EducationMapper.examTypeToApi(request.examType),
      // EXM-6 — optional marks-entry deadline (ISO-8601 UTC), omitted when null.
      if (request.marksEntryDeadline != null)
        'marksEntryDeadline':
            request.marksEntryDeadline!.toUtc().toIso8601String(),
    };
  }

  // ── EXM-3/4/5/7 — report DTO parsers ─────────────────────────────────────

  /// EXM-3 — tabulation register: {classLabel, term, subjects[], students[]}.
  TabulationRegister toTabulation(Map<String, dynamic> json) {
    final subjects = [
      for (final s in (json['subjects'] as List? ?? const [])) '$s',
    ];
    final students = [
      for (final raw in (json['students'] as List? ?? const []))
        if (raw is Map) _toTabulationRow(Map<String, dynamic>.from(raw)),
    ];
    return TabulationRegister(
      classLabel: json['classLabel'] as String? ?? '',
      term: json['term'] as String? ?? '',
      subjects: subjects,
      students: students,
    );
  }

  TabulationStudentRow _toTabulationRow(Map<String, dynamic> json) {
    final perSubjectRaw = json['perSubject'];
    final cells = <String, TabulationCell>{};
    if (perSubjectRaw is Map) {
      perSubjectRaw.forEach((subject, cellRaw) {
        if (cellRaw is Map) {
          final c = Map<String, dynamic>.from(cellRaw);
          cells['$subject'] = TabulationCell(
            subject: '$subject',
            marks: (c['marks'] as num?)?.toInt(),
            maxMarks: (c['maxMarks'] as num?)?.toInt() ?? 0,
            statusCode: c['statusCode'] as String?,
          );
        }
      });
    }
    return TabulationStudentRow(
      studentId: json['studentId'] as String? ?? json['sisStudentId'] as String? ?? '',
      sisStudentId: json['sisStudentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      rollNo: json['rollNo'] as String?,
      cellsBySubject: cells,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalMax: (json['totalMax'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
      rank: (json['rank'] as num?)?.toInt(),
    );
  }

  /// EXM-4a — one subject topper row.
  ExamTopper toTopper(Map<String, dynamic> json) {
    return ExamTopper(
      sisStudentId: json['sisStudentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      rollNo: json['rollNo'] as String?,
      marks: (json['marks'] as num?)?.toInt() ?? 0,
      maxMarks: (json['maxMarks'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
    );
  }

  List<ExamTopper> toToppers(List<dynamic> items) => [
        for (final raw in items)
          if (raw is Map) toTopper(Map<String, dynamic>.from(raw)),
      ];

  /// EXM-4b — one merit-list entry.
  MeritEntry toMeritEntry(Map<String, dynamic> json) {
    return MeritEntry(
      sisStudentId: json['sisStudentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      rollNo: json['rollNo'] as String?,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalMax: (json['totalMax'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
    );
  }

  List<MeritEntry> toMeritList(List<dynamic> items) => [
        for (final raw in items)
          if (raw is Map) toMeritEntry(Map<String, dynamic>.from(raw)),
      ];

  /// EXM-5 — pass/fail + grade distribution.
  ExamGradeDistribution toDistribution(Map<String, dynamic> json) {
    return ExamGradeDistribution(
      examId: json['examId'] as String? ?? '',
      passMarkPercent:
          (json['passMarkPercent'] as num?)?.toInt() ?? kDefaultPassMarkPercent,
      passMarkSource: json['passMarkSource'] as String? ?? 'default',
      passCount: (json['passCount'] as num?)?.toInt() ?? 0,
      failCount: (json['failCount'] as num?)?.toInt() ?? 0,
      gradeBreakdown: [
        for (final raw in (json['gradeBreakdown'] as List? ?? const []))
          if (raw is Map)
            GradeBucket(
              grade: '${(raw)['grade'] ?? ''}',
              count: ((raw)['count'] as num?)?.toInt() ?? 0,
            ),
      ],
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      excludedCount: (json['excludedCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// EXM-7 — one datesheet schedule row.
  DatesheetRow toDatesheetRow(Map<String, dynamic> json) {
    return DatesheetRow(
      examId: json['examId'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      timeLabel: json['timeLabel'] as String? ?? '',
      venueLabel: json['venueLabel'] as String? ?? '',
      maxMarks: (json['maxMarks'] as num?)?.toInt() ?? 0,
    );
  }

  List<DatesheetRow> toDatesheet(List<dynamic> items) => [
        for (final raw in items)
          if (raw is Map) toDatesheetRow(Map<String, dynamic>.from(raw)),
      ];

  // ── EXM-D1/D2/D4/D5 — final exams slice parsers ──────────────────────────

  /// EXM-D1 — one per-student report card (published, effective marks).
  ReportCardData toReportCard(Map<String, dynamic> json) {
    return ReportCardData(
      sisStudentId: json['sisStudentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      classLabel: json['classLabel'] as String? ?? '',
      termLabel: json['termLabel'] as String? ?? '',
      subjects: [
        for (final raw in (json['subjects'] as List? ?? const []))
          if (raw is Map) _toReportCardSubject(Map<String, dynamic>.from(raw)),
      ],
      totalScore: (json['totalScore'] as num?)?.toInt() ?? 0,
      totalMax: (json['totalMax'] as num?)?.toInt() ?? 0,
      overallPercent: (json['overallPercent'] as num?)?.toDouble() ?? 0,
      overallGrade: json['overallGrade'] as String? ?? '',
      rank: (json['rank'] as num?)?.toInt(),
      classSize: (json['classSize'] as num?)?.toInt() ?? 0,
    );
  }

  ReportCardSubject _toReportCardSubject(Map<String, dynamic> json) {
    return ReportCardSubject(
      subject: json['subject'] as String? ?? '',
      examTitle: json['examTitle'] as String? ?? '',
      score: (json['score'] as num?)?.toInt(),
      maxScore: (json['maxScore'] as num?)?.toInt() ?? 0,
      grade: json['grade'] as String? ?? '',
      statusCode: json['statusCode'] as String?,
    );
  }

  List<ReportCardData> toReportCards(List<dynamic> items) => [
        for (final raw in items)
          if (raw is Map) toReportCard(Map<String, dynamic>.from(raw)),
      ];

  /// EXM-D2 — one grace / moderation adjustment record.
  ExamMarkAdjustment toAdjustment(Map<String, dynamic> json) {
    return ExamMarkAdjustment(
      id: json['id'] as String? ?? '',
      examId: json['examId'] as String? ?? '',
      sisStudentId: json['studentId'] as String? ??
          json['sisStudentId'] as String? ?? '',
      delta: (json['delta'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? '',
      adjustedBy: json['adjustedBy'] as String?,
      createdAt: _parseDate(json['createdAt']),
    );
  }

  List<ExamMarkAdjustment> toAdjustments(List<dynamic> items) => [
        for (final raw in items)
          if (raw is Map) toAdjustment(Map<String, dynamic>.from(raw)),
      ];

  /// EXM-D2 — the grace-record response { adjustment, effectiveMark, maxMarks }.
  GraceMarkResult toGraceResult(Map<String, dynamic> json) {
    final adjRaw = json['adjustment'];
    return GraceMarkResult(
      adjustment: adjRaw is Map
          ? toAdjustment(Map<String, dynamic>.from(adjRaw))
          : const ExamMarkAdjustment(
              id: '', examId: '', sisStudentId: '', delta: 0, reason: ''),
      effectiveMark: (json['effectiveMark'] as num?)?.toInt(),
      maxMarks: (json['maxMarks'] as num?)?.toInt() ?? 0,
    );
  }

  /// EXM-D2 — request body for a grace adjustment.
  Map<String, dynamic> graceBody({required int delta, required String reason}) {
    return {'delta': delta, 'reason': reason};
  }

  /// EXM-D4 — one hall ticket (admit card).
  HallTicket toHallTicket(Map<String, dynamic> json) {
    return HallTicket(
      sisStudentId: json['sisStudentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      rollNo: json['rollNo'] as String?,
      classLabel: json['classLabel'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      examTitle: json['examTitle'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      timeLabel: json['timeLabel'] as String? ?? '',
      venueLabel: json['venueLabel'] as String? ?? '',
      maxMarks: (json['maxMarks'] as num?)?.toInt() ?? 0,
      instructions: [
        for (final s in (json['instructions'] as List? ?? const [])) '$s',
      ],
    );
  }

  List<HallTicket> toHallTickets(List<dynamic> items) => [
        for (final raw in items)
          if (raw is Map) toHallTicket(Map<String, dynamic>.from(raw)),
      ];

  /// EXM-D5 — the seating plan { examId, roomCapacity, rooms[] }.
  SeatingPlan toSeatingPlan(Map<String, dynamic> json) {
    return SeatingPlan(
      examId: json['examId'] as String? ?? '',
      roomCapacity: (json['roomCapacity'] as num?)?.toInt() ??
          kDefaultSeatingRoomCapacity,
      rooms: [
        for (final raw in (json['rooms'] as List? ?? const []))
          if (raw is Map) _toSeatingRoom(Map<String, dynamic>.from(raw)),
      ],
    );
  }

  SeatingRoom _toSeatingRoom(Map<String, dynamic> json) {
    return SeatingRoom(
      roomLabel: json['roomLabel'] as String? ?? '',
      seats: [
        for (final raw in (json['seats'] as List? ?? const []))
          if (raw is Map) _toSeatingSeat(Map<String, dynamic>.from(raw)),
      ],
    );
  }

  SeatingSeat _toSeatingSeat(Map<String, dynamic> json) {
    return SeatingSeat(
      seatNo: (json['seatNo'] as num?)?.toInt() ?? 0,
      sisStudentId: json['sisStudentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      rollNo: json['rollNo'] as String?,
      classLabel: json['classLabel'] as String? ?? '',
    );
  }

  ExamLifecyclePhase _phaseFromApi(String value) => switch (value) {
        'scheduled' => ExamLifecyclePhase.scheduled,
        'marks_entry' => ExamLifecyclePhase.marksEntry,
        'processed' => ExamLifecyclePhase.processed,
        'published' => ExamLifecyclePhase.published,
        _ => ExamLifecyclePhase.draft,
      };
}
