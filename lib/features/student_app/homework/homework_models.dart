import 'package:flutter/foundation.dart';

/// Per-student homework lifecycle: pending → submitted → reviewed (terminal),
/// with overdue as the unsubmitted-and-past-due branch. `reviewed` is set once
/// the teacher grades *this* student's submission, so two students on the same
/// assignment can sit at different stages.
enum StudentHomeworkStatus { pending, submitted, reviewed, overdue }

enum StudentHomeworkFilter { all, pending, submitted }

extension StudentHomeworkStatusX on StudentHomeworkStatus {
  String get label => switch (this) {
        StudentHomeworkStatus.pending => 'Pending',
        StudentHomeworkStatus.submitted => 'Submitted',
        StudentHomeworkStatus.reviewed => 'Reviewed',
        StudentHomeworkStatus.overdue => 'Overdue',
      };

  /// A submission that has been handed in (whether or not it is graded yet).
  /// `reviewed` is a terminal sub-state of submitted, so it counts here too.
  bool get isSubmitted =>
      this == StudentHomeworkStatus.submitted ||
      this == StudentHomeworkStatus.reviewed;
}

extension StudentHomeworkFilterX on StudentHomeworkFilter {
  String get label => switch (this) {
        StudentHomeworkFilter.all => 'All',
        StudentHomeworkFilter.pending => 'Pending',
        StudentHomeworkFilter.submitted => 'Submitted',
      };
}

@immutable
class StudentHomeworkItem {
  const StudentHomeworkItem({
    required this.id,
    required this.subject,
    required this.title,
    required this.dueLabel,
    required this.status,
    this.attachmentLabel,
    this.submittedLabel,
    this.reviewGrade,
    this.reviewComment,
  });

  final String id;
  final String subject;
  final String title;
  final String dueLabel;
  final StudentHomeworkStatus status;
  final String? attachmentLabel;
  final String? submittedLabel;

  /// Teacher's grade + comment once the submission is reviewed (null otherwise).
  final String? reviewGrade;
  final String? reviewComment;

  bool get hasAttachment => attachmentLabel != null;
  bool get isReviewed => reviewGrade != null;
}

@immutable
class StudentHomeworkData {
  const StudentHomeworkData({
    required this.studentName,
    required this.classLabel,
    required this.items,
    this.unreadNotifications = 0,
  });

  final String studentName;
  final String classLabel;
  final List<StudentHomeworkItem> items;
  final int unreadNotifications;

  int get pendingCount =>
      items.where((i) => i.status == StudentHomeworkStatus.pending).length;
  int get submittedCount => items.where((i) => i.status.isSubmitted).length;
  int get reviewedCount =>
      items.where((i) => i.status == StudentHomeworkStatus.reviewed).length;
  int get overdueCount =>
      items.where((i) => i.status == StudentHomeworkStatus.overdue).length;
}
