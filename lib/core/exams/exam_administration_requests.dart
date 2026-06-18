import '../../features/education/education_models.dart';

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
  });

  final String markEntryId;
  final int marksObtained;
}
