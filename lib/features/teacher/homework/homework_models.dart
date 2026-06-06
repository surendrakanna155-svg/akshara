import 'package:flutter/foundation.dart';

enum HomeworkReviewStatus { pending, reviewed }

extension HomeworkReviewStatusX on HomeworkReviewStatus {
  String get label => switch (this) {
        HomeworkReviewStatus.pending => 'Pending review',
        HomeworkReviewStatus.reviewed => 'Reviewed',
      };
}

@immutable
class HomeworkSubmission {
  const HomeworkSubmission({
    required this.id,
    required this.studentName,
    required this.classLabel,
    required this.title,
    required this.submittedLabel,
    required this.status,
    this.grade,
    this.comment,
  });

  final String id;
  final String studentName;
  final String classLabel;
  final String title;
  final String submittedLabel;
  final HomeworkReviewStatus status;
  final String? grade;
  final String? comment;

  HomeworkSubmission copyWith({
    HomeworkReviewStatus? status,
    String? grade,
    String? comment,
  }) {
    return HomeworkSubmission(
      id: id,
      studentName: studentName,
      classLabel: classLabel,
      title: title,
      submittedLabel: submittedLabel,
      status: status ?? this.status,
      grade: grade ?? this.grade,
      comment: comment ?? this.comment,
    );
  }
}

@immutable
class TeacherHomeworkAssignment {
  const TeacherHomeworkAssignment({
    required this.id,
    required this.title,
    required this.classLabel,
    required this.dueLabel,
    required this.submissions,
  });

  final String id;
  final String title;
  final String classLabel;
  final String dueLabel;
  final List<HomeworkSubmission> submissions;

  int get pendingCount => submissions
      .where((s) => s.status == HomeworkReviewStatus.pending)
      .length;
}
