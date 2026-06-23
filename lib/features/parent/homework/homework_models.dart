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
    this.reviewGrade,
    this.reviewComment,
  });

  final String id;
  final String subject;
  final String title;
  final String dueLabel;
  final ParentHomeworkStatus status;

  /// Teacher's grade + comment once reviewed (null otherwise).
  final String? reviewGrade;
  final String? reviewComment;

  bool get isReviewed => reviewGrade != null;
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

  int get pendingCount =>
      items.where((item) => item.status == ParentHomeworkStatus.pending).length;
  int get submittedCount =>
      items.where((item) => item.status.isSubmitted).length;
  int get reviewedCount => items
      .where((item) => item.status == ParentHomeworkStatus.reviewed)
      .length;
  int get overdueCount =>
      items.where((item) => item.status == ParentHomeworkStatus.overdue).length;

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
