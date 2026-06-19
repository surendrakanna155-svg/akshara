/// Who authored an exam-session remark. Class teacher is the primary author;
/// principal/vice-principal are reserved for the future extension.
enum ExamRemarkAuthorRole { classTeacher, principal, vicePrincipal }

ExamRemarkAuthorRole examRemarkAuthorRoleFromName(String? name) {
  return ExamRemarkAuthorRole.values.firstWhere(
    (r) => r.name == name,
    orElse: () => ExamRemarkAuthorRole.classTeacher,
  );
}

/// One entry in a remark's audit trail.
class ExamRemarkRevision {
  const ExamRemarkRevision({
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.timestamp,
  });

  final String text;
  final String authorId;
  final String authorName;
  final ExamRemarkAuthorRole authorRole;
  final String timestamp; // ISO-8601

  Map<String, dynamic> toJson() => {
        'text': text,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole.name,
        'timestamp': timestamp,
      };

  factory ExamRemarkRevision.fromJson(Map<String, dynamic> json) =>
      ExamRemarkRevision(
        text: '${json['text'] ?? ''}',
        authorId: '${json['authorId'] ?? ''}',
        authorName: '${json['authorName'] ?? ''}',
        authorRole: examRemarkAuthorRoleFromName(json['authorRole'] as String?),
        timestamp: '${json['timestamp'] ?? ''}',
      );
}

/// A remark for one student on one exam session. One per (student, exam session);
/// schools issue independent remarks for Unit Tests, Quarterly, Half-Yearly,
/// Annual, etc. Carries an audit trail of every edit.
class ExamRemark {
  const ExamRemark({
    required this.examId,
    required this.sisStudentId,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    required this.updatedAt,
    required this.history,
  });

  final String examId;
  final String sisStudentId;
  final String text;
  final String authorId;
  final String authorName;
  final ExamRemarkAuthorRole authorRole;
  final String createdAt;
  final String updatedAt;

  /// Audit trail, oldest first; the last entry matches the current [text].
  final List<ExamRemarkRevision> history;

  Map<String, dynamic> toJson() => {
        'examId': examId,
        'sisStudentId': sisStudentId,
        'text': text,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole.name,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'history': [for (final r in history) r.toJson()],
      };

  factory ExamRemark.fromJson(Map<String, dynamic> json) => ExamRemark(
        examId: '${json['examId'] ?? ''}',
        sisStudentId: '${json['sisStudentId'] ?? ''}',
        text: '${json['text'] ?? ''}',
        authorId: '${json['authorId'] ?? ''}',
        authorName: '${json['authorName'] ?? ''}',
        authorRole: examRemarkAuthorRoleFromName(json['authorRole'] as String?),
        createdAt: '${json['createdAt'] ?? ''}',
        updatedAt: '${json['updatedAt'] ?? ''}',
        history: [
          for (final raw in (json['history'] as List? ?? const []))
            if (raw is Map)
              ExamRemarkRevision.fromJson(Map<String, dynamic>.from(raw)),
        ],
      );
}
