class MeetingActionItem {
  const MeetingActionItem({
    required this.id,
    required this.title,
    this.owner,
    this.dueDate,
    this.completed = false,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? owner;
  final DateTime? dueDate;
  final bool completed;
  final DateTime? completedAt;

  MeetingActionItem copyWith({
    String? id,
    String? title,
    String? owner,
    DateTime? dueDate,
    bool? completed,
    DateTime? completedAt,
  }) {
    return MeetingActionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      owner: owner ?? this.owner,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class MeetingFollowUp {
  const MeetingFollowUp({
    required this.id,
    required this.meetingId,
    required this.scheduledAt,
    required this.channel,
    required this.status,
    this.notes,
  });

  final String id;
  final String meetingId;
  final DateTime scheduledAt;
  final String channel;
  final String status;
  final String? notes;

  MeetingFollowUp copyWith({
    String? id,
    String? meetingId,
    DateTime? scheduledAt,
    String? channel,
    String? status,
    String? notes,
  }) {
    return MeetingFollowUp(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      channel: channel ?? this.channel,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

class ParentMeetingRecord {
  const ParentMeetingRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.parentName,
    required this.teacherName,
    required this.meetingAt,
    required this.notes,
    this.aiSummary,
    this.actionItems = const [],
    this.followUps = const [],
    this.lastUpdatedAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String parentName;
  final String teacherName;
  final DateTime meetingAt;
  final String notes;
  final String? aiSummary;
  final List<MeetingActionItem> actionItems;
  final List<MeetingFollowUp> followUps;
  final DateTime? lastUpdatedAt;

  ParentMeetingRecord copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? parentName,
    String? teacherName,
    DateTime? meetingAt,
    String? notes,
    String? aiSummary,
    List<MeetingActionItem>? actionItems,
    List<MeetingFollowUp>? followUps,
    DateTime? lastUpdatedAt,
  }) {
    return ParentMeetingRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      parentName: parentName ?? this.parentName,
      teacherName: teacherName ?? this.teacherName,
      meetingAt: meetingAt ?? this.meetingAt,
      notes: notes ?? this.notes,
      aiSummary: aiSummary ?? this.aiSummary,
      actionItems: actionItems ?? this.actionItems,
      followUps: followUps ?? this.followUps,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
