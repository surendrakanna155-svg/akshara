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
    this.dueDate,
    this.attachmentLabel,
    this.submittedLabel,
    this.reviewGrade,
    this.reviewComment,
  });

  final String id;
  final String subject;
  final String title;
  final String dueLabel;

  /// HWK-1 — the real machine-readable due date (ISO `YYYY-MM-DD`), when the
  /// assignment carries one. Null for legacy label-only homework.
  final String? dueDate;

  final StudentHomeworkStatus status;
  final String? attachmentLabel;
  final String? submittedLabel;

  /// Teacher's grade + comment once the submission is reviewed (null otherwise).
  final String? reviewGrade;
  final String? reviewComment;

  bool get hasAttachment => attachmentLabel != null;
  bool get isReviewed => reviewGrade != null;

  /// HWK-1 — the effective display status derived from the real [dueDate]: a
  /// still-pending item whose due date is strictly in the past reads as overdue.
  /// Terminal states (submitted/reviewed) and items without a dueDate keep their
  /// raw [status]. Mirrors the backend `deriveHomeworkDisplayStatus` so the UI
  /// is correct even if it receives a raw `pending` past its due date.
  StudentHomeworkStatus get effectiveStatus =>
      deriveStudentHomeworkStatus(status, dueDate);
}

/// Pure client-side overdue derivation (belt-and-suspenders to the backend
/// overlay). Kept top-level so it is unit-testable.
StudentHomeworkStatus deriveStudentHomeworkStatus(
  StudentHomeworkStatus rawStatus,
  String? isoDueDate, {
  DateTime? today,
}) {
  if (rawStatus != StudentHomeworkStatus.pending) return rawStatus;
  return _isHomeworkPastDue(isoDueDate, today: today)
      ? StudentHomeworkStatus.overdue
      : rawStatus;
}

/// True only when [isoDueDate] is a valid `YYYY-MM-DD` strictly before today.
bool _isHomeworkPastDue(String? isoDueDate, {DateTime? today}) {
  if (isoDueDate == null) return false;
  final due = DateTime.tryParse(isoDueDate);
  if (due == null) return false;
  final now = today ?? DateTime.now();
  final todayDate = DateTime(now.year, now.month, now.day);
  final dueDate = DateTime(due.year, due.month, due.day);
  return dueDate.isBefore(todayDate);
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

  int get pendingCount => items
      .where((i) => i.effectiveStatus == StudentHomeworkStatus.pending)
      .length;
  int get submittedCount =>
      items.where((i) => i.effectiveStatus.isSubmitted).length;
  int get reviewedCount => items
      .where((i) => i.effectiveStatus == StudentHomeworkStatus.reviewed)
      .length;
  int get overdueCount => items
      .where((i) => i.effectiveStatus == StudentHomeworkStatus.overdue)
      .length;
}
