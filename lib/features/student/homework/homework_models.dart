import 'package:flutter/foundation.dart';

enum StudentHomeworkStatus { pending, submitted, overdue }

enum StudentHomeworkFilter { all, pending, submitted }

extension StudentHomeworkStatusX on StudentHomeworkStatus {
  String get label => switch (this) {
        StudentHomeworkStatus.pending => 'Pending',
        StudentHomeworkStatus.submitted => 'Submitted',
        StudentHomeworkStatus.overdue => 'Overdue',
      };
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
  });

  final String id;
  final String subject;
  final String title;
  final String dueLabel;
  final StudentHomeworkStatus status;
  final String? attachmentLabel;
  final String? submittedLabel;

  bool get hasAttachment => attachmentLabel != null;
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
  int get submittedCount =>
      items.where((i) => i.status == StudentHomeworkStatus.submitted).length;
  int get overdueCount =>
      items.where((i) => i.status == StudentHomeworkStatus.overdue).length;
}
