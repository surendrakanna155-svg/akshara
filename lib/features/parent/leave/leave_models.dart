import 'package:flutter/foundation.dart';

/// Leave request lifecycle states for PA-12.
enum LeaveStatus { pending, approved, rejected, cancelled }

extension LeaveStatusX on LeaveStatus {
  String get label {
    return switch (this) {
      LeaveStatus.pending => 'Pending',
      LeaveStatus.approved => 'Approved',
      LeaveStatus.rejected => 'Rejected',
      LeaveStatus.cancelled => 'Cancelled',
    };
  }
}

/// Leave application types.
enum LeaveType { sick, personal, family, other }

extension LeaveTypeX on LeaveType {
  String get label {
    return switch (this) {
      LeaveType.sick => 'Sick leave',
      LeaveType.personal => 'Personal',
      LeaveType.family => 'Family event',
      LeaveType.other => 'Other',
    };
  }
}

/// Active tab in PA-12 screen.
enum LeaveScreenSection { history, apply }

/// Timeline step in leave approval flow.
@immutable
class LeaveTimelineStep {
  const LeaveTimelineStep({
    required this.label,
    required this.dateLabel,
    required this.isComplete,
    this.note,
  });

  final String label;
  final String dateLabel;
  final bool isComplete;
  final String? note;
}

/// Parent-submitted leave request for a child.
@immutable
class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.childName,
    required this.childClass,
    required this.fromDateLabel,
    required this.toDateLabel,
    required this.reason,
    required this.type,
    required this.status,
    required this.submittedLabel,
    required this.timeline,
    this.hasAttachment = false,
    this.attachmentName,
  });

  final String id;
  final String childName;
  final String childClass;
  final String fromDateLabel;
  final String toDateLabel;
  final String reason;
  final LeaveType type;
  final LeaveStatus status;
  final String submittedLabel;
  final List<LeaveTimelineStep> timeline;
  final bool hasAttachment;
  final String? attachmentName;
}

/// Draft apply-leave form state.
@immutable
class LeaveApplyDraft {
  const LeaveApplyDraft({
    this.fromDateLabel = '',
    this.toDateLabel = '',
    this.reason = '',
    this.type = LeaveType.sick,
    this.hasAttachment = false,
    this.attachmentName,
  });

  final String fromDateLabel;
  final String toDateLabel;
  final String reason;
  final LeaveType type;
  final bool hasAttachment;
  final String? attachmentName;

  bool get isValid =>
      fromDateLabel.isNotEmpty &&
      toDateLabel.isNotEmpty &&
      reason.trim().length >= 8;

  /// True when nothing has been entered yet (nothing worth persisting).
  bool get isEmpty =>
      fromDateLabel.isEmpty &&
      toDateLabel.isEmpty &&
      reason.trim().isEmpty &&
      type == LeaveType.sick &&
      !hasAttachment;

  LeaveApplyDraft copyWith({
    String? fromDateLabel,
    String? toDateLabel,
    String? reason,
    LeaveType? type,
    bool? hasAttachment,
    String? attachmentName,
  }) {
    return LeaveApplyDraft(
      fromDateLabel: fromDateLabel ?? this.fromDateLabel,
      toDateLabel: toDateLabel ?? this.toDateLabel,
      reason: reason ?? this.reason,
      type: type ?? this.type,
      hasAttachment: hasAttachment ?? this.hasAttachment,
      attachmentName: attachmentName ?? this.attachmentName,
    );
  }

  /// Serialise the in-progress form for draft persistence (design §5).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'fromDateLabel': fromDateLabel,
        'toDateLabel': toDateLabel,
        'reason': reason,
        'type': type.name,
        'hasAttachment': hasAttachment,
        'attachmentName': attachmentName,
      };

  factory LeaveApplyDraft.fromJson(Map<String, dynamic> json) {
    return LeaveApplyDraft(
      fromDateLabel: json['fromDateLabel'] as String? ?? '',
      toDateLabel: json['toDateLabel'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      type: LeaveType.values.firstWhere(
        (LeaveType t) => t.name == json['type'],
        orElse: () => LeaveType.sick,
      ),
      hasAttachment: json['hasAttachment'] as bool? ?? false,
      attachmentName: json['attachmentName'] as String?,
    );
  }
}
