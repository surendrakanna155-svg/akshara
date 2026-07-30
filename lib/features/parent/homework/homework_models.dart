import 'package:flutter/foundation.dart';

/// Homework completion states shown in the parent module. Mirrors the per-student
/// lifecycle: pending → submitted → reviewed (terminal), overdue = unsubmitted +
/// past due. `reviewed` is set once the teacher grades this child's submission.
enum ParentHomeworkStatus { pending, submitted, reviewed, overdue }

/// Parent-facing homework filter options.
enum HomeworkFilter { all, pending, submitted, overdue }

extension HomeworkFilterX on HomeworkFilter {
  String get label {
    return switch (this) {
      HomeworkFilter.all => 'All',
      HomeworkFilter.pending => 'Pending',
      HomeworkFilter.submitted => 'Submitted',
      HomeworkFilter.overdue => 'Overdue',
    };
  }
}

extension ParentHomeworkStatusX on ParentHomeworkStatus {
  String get label {
    return switch (this) {
      ParentHomeworkStatus.pending => 'Pending',
      ParentHomeworkStatus.submitted => 'Submitted',
      ParentHomeworkStatus.reviewed => 'Reviewed',
      ParentHomeworkStatus.overdue => 'Overdue',
    };
  }

  /// Handed in (graded or not) — `reviewed` is a terminal sub-state of submitted.
  bool get isSubmitted =>
      this == ParentHomeworkStatus.submitted ||
      this == ParentHomeworkStatus.reviewed;
}

/// Single homework row model for parent homework list.
@immutable
class ParentHomeworkItem {
  const ParentHomeworkItem({
    required this.id,
    required this.subject,
    required this.title,
    required this.dueLabel,
    required this.status,
    this.dueDate,
    this.reviewGrade,
    this.reviewComment,
    this.attachmentLabel,
    this.attachmentRef,
    this.submissionNote,
    this.submissionAttachmentLabel,
  });

  final String id;
  final String subject;
  final String title;
  final String dueLabel;

  /// HWK-1 — the real machine-readable due date (ISO `YYYY-MM-DD`), when the
  /// assignment carries one. Null for legacy label-only homework.
  final String? dueDate;

  final ParentHomeworkStatus status;

  /// Teacher's grade + comment once reviewed (null otherwise).
  final String? reviewGrade;
  final String? reviewComment;

  /// HWK-4 — the teacher's attachment on the assignment (reference/label, not a
  /// real uploaded file). [attachmentLabel] is the display name; [attachmentRef]
  /// an optional URL/reference.
  final String? attachmentLabel;
  final String? attachmentRef;

  /// HWK-7 — the child's own submission note + attachment reference, once handed
  /// in. Null before submission.
  final String? submissionNote;
  final String? submissionAttachmentLabel;

  bool get isReviewed => reviewGrade != null;
  bool get hasTeacherAttachment => attachmentLabel != null;

  /// HWK-1 — display status derived from the real [dueDate]: a still-pending
  /// item past its due date reads as overdue. Mirrors the backend derivation.
  ParentHomeworkStatus get effectiveStatus =>
      deriveParentHomeworkStatus(status, dueDate);
}

/// Pure client-side overdue derivation (belt-and-suspenders to the backend
/// overlay). Kept top-level so it is unit-testable.
ParentHomeworkStatus deriveParentHomeworkStatus(
  ParentHomeworkStatus rawStatus,
  String? isoDueDate, {
  DateTime? today,
}) {
  if (rawStatus != ParentHomeworkStatus.pending) return rawStatus;
  if (isoDueDate == null) return rawStatus;
  final due = DateTime.tryParse(isoDueDate);
  if (due == null) return rawStatus;
  final now = today ?? DateTime.now();
  final todayDate = DateTime(now.year, now.month, now.day);
  final dueDate = DateTime(due.year, due.month, due.day);
  return dueDate.isBefore(todayDate)
      ? ParentHomeworkStatus.overdue
      : rawStatus;
}

/// Parent homework screen payload with KPI-friendly helpers.
@immutable
class ParentHomeworkData {
  const ParentHomeworkData({
    required this.childName,
    required this.childClass,
    required this.items,
    required this.insightMessage,
    required this.insightActionLabel,
    this.unreadNotifications = 0,
  });

  final String childName;
  final String childClass;
  final List<ParentHomeworkItem> items;
  final String insightMessage;
  final String insightActionLabel;
  final int unreadNotifications;

  int get pendingCount => items
      .where((item) => item.effectiveStatus == ParentHomeworkStatus.pending)
      .length;
  int get submittedCount =>
      items.where((item) => item.effectiveStatus.isSubmitted).length;
  int get reviewedCount => items
      .where((item) => item.effectiveStatus == ParentHomeworkStatus.reviewed)
      .length;
  int get overdueCount => items
      .where((item) => item.effectiveStatus == ParentHomeworkStatus.overdue)
      .length;

  /// Honest-async contract neutral shape (CERT-002) — no child, no tasks, no
  /// due dates, no coaching insight.
  factory ParentHomeworkData.empty() {
    return const ParentHomeworkData(
      childName: '',
      childClass: '',
      items: [],
      insightMessage: '',
      insightActionLabel: '',
    );
  }

  factory ParentHomeworkData.mock() {
    return const ParentHomeworkData(
      childName: 'Ravi Kumar',
      childClass: '8-A',
      unreadNotifications: 2,
      insightMessage:
          'Math and Science tasks are due this week - schedule 30 minutes daily.',
      insightActionLabel: 'View plan',
      items: [
        ParentHomeworkItem(
          id: 'hw_1',
          subject: 'Mathematics',
          title: 'Exercise 5.2 - Solve Q1 to Q8',
          dueLabel: 'Due today',
          status: ParentHomeworkStatus.pending,
        ),
        ParentHomeworkItem(
          id: 'hw_2',
          subject: 'Science',
          title: 'Write notes on photosynthesis',
          dueLabel: 'Due 08 Jun',
          status: ParentHomeworkStatus.pending,
        ),
        ParentHomeworkItem(
          id: 'hw_3',
          subject: 'English',
          title: 'Poem recitation preparation',
          dueLabel: 'Submitted 05 Jun',
          status: ParentHomeworkStatus.submitted,
        ),
        ParentHomeworkItem(
          id: 'hw_4',
          subject: 'Social',
          title: 'Map labeling: India rivers',
          dueLabel: 'Due 04 Jun',
          status: ParentHomeworkStatus.overdue,
        ),
        ParentHomeworkItem(
          id: 'hw_5',
          subject: 'Hindi',
          title: 'Grammar worksheet - Sangya',
          dueLabel: 'Submitted 03 Jun',
          status: ParentHomeworkStatus.submitted,
        ),
        ParentHomeworkItem(
          id: 'hw_6',
          subject: 'Computer',
          title: 'Scratch animation mini-project',
          dueLabel: 'Due 10 Jun',
          status: ParentHomeworkStatus.pending,
        ),
      ],
    );
  }
}
