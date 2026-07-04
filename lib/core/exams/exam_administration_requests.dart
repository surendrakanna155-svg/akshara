import '../../features/education/education_models.dart';
import 'exam_administration_store.dart';

/// Domain request to create an exam session (draft phase).
class CreateExamAdministrationRequest {
  const CreateExamAdministrationRequest({
    required this.title,
    required this.subject,
    required this.grade,
    required this.section,
    required this.termLabel,
    required this.dateLabel,
    required this.timeLabel,
    required this.venueLabel,
    required this.syllabusLabel,
    required this.maxMarks,
    this.examType = EduExamType.unitTest,
    this.marksEntryDeadline,
  });

  final String title;
  final String subject;
  final String grade;
  final String section;
  final String termLabel;
  final String dateLabel;
  final String timeLabel;
  final String venueLabel;
  final String syllabusLabel;
  final int maxMarks;
  final EduExamType examType;

  /// EXM-6 — optional soft marks-entry deadline (UTC), null when unset.
  final DateTime? marksEntryDeadline;
}

/// Domain request to update a mark entry before publish.
class UpdateExamMarkRequest {
  const UpdateExamMarkRequest({
    required this.markEntryId,
    required this.marksObtained,
    this.status = ExamMarkStatus.present,
    this.expectedVersion,
  });

  final String markEntryId;

  /// The entered marks for a present student. Ignored (forced null) when
  /// [status] is not [ExamMarkStatus.present].
  final int marksObtained;

  /// EXM-D6 — attendance status. A non-present status marks the student
  /// absent/medical/debarred and clears their marks.
  final ExamMarkStatus status;

  /// REL-5 — the `row_version` this edit was based on. Sent as `expectedVersion`
  /// so the backend's optimistic-lock guard rejects a stale overwrite on the
  /// FIRST write (not only on a post-conflict retry). Null ⇒ unconditional write.
  final int? expectedVersion;
}

/// EXM-1 — one entry inside a fast bulk marks save. A non-present ([status] not
/// present) entry has null [marksObtained] (marks are forced null server-side).
class BulkExamMarkEntry {
  const BulkExamMarkEntry({
    required this.markEntryId,
    this.marksObtained,
    this.status = ExamMarkStatus.present,
  });

  final String markEntryId;
  final int? marksObtained;
  final ExamMarkStatus status;
}

/// EXM-1 — a fast bulk marks save for one exam. Applied per-row server-side:
/// published rows are skipped + reported (never overwritten), the rest persist
/// (partial success).
class BulkUpdateExamMarksRequest {
  const BulkUpdateExamMarksRequest({
    required this.examId,
    required this.entries,
  });

  final String examId;
  final List<BulkExamMarkEntry> entries;
}
