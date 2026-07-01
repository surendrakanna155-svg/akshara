import '../../../../exams/exam_administration_requests.dart';
import '../../../../exams/exam_administration_store.dart';
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
    );
  }

  List<ExamSession> toSessions(List<dynamic> items) =>
      items.map((item) => toSession(item as Map<String, dynamic>)).toList();

  ExamMarkRecord toMark(Map<String, dynamic> json) {
    final marksRaw = json['marksObtained'] ?? json['marks_obtained'];
    final status = ExamMarkStatus.fromWire(
      json['status'] as String? ?? json['attendance_status'] as String?,
    );
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
    };
  }

  ExamLifecyclePhase _phaseFromApi(String value) => switch (value) {
        'scheduled' => ExamLifecyclePhase.scheduled,
        'marks_entry' => ExamLifecyclePhase.marksEntry,
        'processed' => ExamLifecyclePhase.processed,
        'published' => ExamLifecyclePhase.published,
        _ => ExamLifecyclePhase.draft,
      };
}
