/// Domain request to submit homework from the student app.
///
/// PRA-P1-30: [attachmentStoragePath] is the tenant-prefixed path of the REAL
/// object the client already PUT to Storage via the presign step. [attachmentLabel]
/// remains the human display label. The backend rejects a foreign-tenant path.
class StudentHomeworkSubmitRequest {
  const StudentHomeworkSubmitRequest({
    required this.homeworkId,
    this.attachmentLabel,
    this.notes = '',
    this.attachmentStoragePath,
  });

  final String homeworkId;
  final String? attachmentLabel;
  final String notes;
  final String? attachmentStoragePath;
}
