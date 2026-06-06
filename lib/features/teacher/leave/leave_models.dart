import 'package:flutter/foundation.dart';

enum TeacherLeaveStatus { pending, approved, rejected }

extension TeacherLeaveStatusX on TeacherLeaveStatus {
  String get label => switch (this) {
        TeacherLeaveStatus.pending => 'Pending',
        TeacherLeaveStatus.approved => 'Approved',
        TeacherLeaveStatus.rejected => 'Rejected',
      };
}

enum TeacherLeaveSection { apply, history }

@immutable
class LeaveBalance {
  const LeaveBalance({
    required this.casualRemaining,
    required this.sickRemaining,
    required this.earnedRemaining,
  });

  final int casualRemaining;
  final int sickRemaining;
  final int earnedRemaining;
}

@immutable
class LeaveTimelineStep {
  const LeaveTimelineStep({
    required this.label,
    required this.dateLabel,
    required this.isComplete,
  });

  final String label;
  final String dateLabel;
  final bool isComplete;
}

@immutable
class TeacherLeaveRequest {
  const TeacherLeaveRequest({
    required this.id,
    required this.typeLabel,
    required this.fromDateLabel,
    required this.toDateLabel,
    required this.reason,
    required this.status,
    required this.timeline,
  });

  final String id;
  final String typeLabel;
  final String fromDateLabel;
  final String toDateLabel;
  final String reason;
  final TeacherLeaveStatus status;
  final List<LeaveTimelineStep> timeline;
}

@immutable
class TeacherLeaveApplyDraft {
  const TeacherLeaveApplyDraft({
    this.typeLabel = 'Casual leave',
    this.fromDateLabel = '',
    this.toDateLabel = '',
    this.reason = '',
  });

  final String typeLabel;
  final String fromDateLabel;
  final String toDateLabel;
  final String reason;

  bool get isValid =>
      fromDateLabel.isNotEmpty &&
      toDateLabel.isNotEmpty &&
      reason.trim().length >= 8;

  TeacherLeaveApplyDraft copyWith({
    String? typeLabel,
    String? fromDateLabel,
    String? toDateLabel,
    String? reason,
  }) {
    return TeacherLeaveApplyDraft(
      typeLabel: typeLabel ?? this.typeLabel,
      fromDateLabel: fromDateLabel ?? this.fromDateLabel,
      toDateLabel: toDateLabel ?? this.toDateLabel,
      reason: reason ?? this.reason,
    );
  }
}
