/// Domain request to submit homework from the student app.
class StudentHomeworkSubmitRequest {
  const StudentHomeworkSubmitRequest({
    required this.homeworkId,
    this.attachmentLabel,
    this.notes = '',
  });

  final String homeworkId;
  final String? attachmentLabel;
  final String notes;
}
