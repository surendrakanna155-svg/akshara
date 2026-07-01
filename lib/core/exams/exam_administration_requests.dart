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
}

/// Domain request to update a mark entry before publish.
class UpdateExamMarkRequest {
  const UpdateExamMarkRequest({
    required this.markEntryId,
    required this.marksObtained,
    this.status = ExamMarkStatus.present,
  });

  final String markEntryId;

  /// The entered marks for a present student. Ignored (forced null) when
  /// [status] is not [ExamMarkStatus.present].
  final int marksObtained;

  /// EXM-D6 — attendance status. A non-present status marks the student
  /// absent/medical/debarred and clears their marks.
  final ExamMarkStatus status;
}
