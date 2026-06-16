import '../../../features/parent_meetings/parent_meeting_models.dart';
import '../../../features/parent_meetings/parent_meetings_repository.dart';
import '../repository_query.dart';

class MockParentMeetingsRepository implements ParentMeetingsRepository {
  final List<ParentMeetingRecord> _meetings = [
    ParentMeetingRecord(
      id: 'pm_1',
      studentId: 'STU_1001',
      studentName: 'Aarav Nair',
      parentName: 'Maya Nair',
      teacherName: 'Ms. Preethi',
      meetingAt: DateTime(2026, 6, 10, 10, 30),
      notes:
          'Attendance improved. Math worksheet completion is inconsistent. Parent requested weekly checkpoint.',
      actionItems: [
        MeetingActionItem(
          id: 'act_1',
          title: 'Share weekly math practice worksheet',
          owner: 'Teacher',
          dueDate: DateTime(2026, 6, 18),
          completed: false,
        ),
        MeetingActionItem(
          id: 'act_2',
          title: 'Track homework completion daily',
          owner: 'Parent',
          dueDate: DateTime(2026, 6, 18),
          completed: true,
          completedAt: DateTime(2026, 6, 12),
        ),
      ],
      followUps: [
        MeetingFollowUp(
          id: 'fu_1',
          meetingId: 'pm_1',
          scheduledAt: DateTime(2026, 6, 19, 17, 00),
          channel: 'call',
          status: 'scheduled',
          notes: 'Discuss progress against action items',
        ),
      ],
      aiSummary:
          'Parent and teacher aligned on improving homework consistency. Weekly check-ins and worksheet tracking agreed.',
      lastUpdatedAt: DateTime(2026, 6, 12, 17, 30),
    ),
    ParentMeetingRecord(
      id: 'pm_ravi',
      studentId: 'SIS-STU-10430',
      studentName: 'Ravi Kumar',
      parentName: 'Suresh Kumar',
      teacherName: 'Mrs. Sharma',
      meetingAt: DateTime(2026, 6, 15, 14, 0),
      notes: 'Discuss mid-term performance and transport timing.',
      actionItems: [
        MeetingActionItem(
          id: 'act_ravi_1',
          title: 'Confirm PTM slot for 15 June',
          owner: 'Parent',
          dueDate: DateTime(2026, 6, 14),
          completed: false,
        ),
      ],
      followUps: const [],
      aiSummary:
          'PTM scheduled for 15 June. Focus on mathematics revision plan.',
      lastUpdatedAt: DateTime(2026, 6, 5, 10, 0),
    ),
  ];

  @override
  Future<List<ParentMeetingRecord>> listMeetings({
    required RepositoryQuery query,
  }) async {
    return List<ParentMeetingRecord>.from(_meetings);
  }

  @override
  Future<ParentMeetingRecord> createMeeting({
    required RepositoryQuery query,
    required String studentId,
    required String studentName,
    required String parentName,
    required String teacherName,
    required DateTime meetingAt,
    String notes = '',
  }) async {
    final record = ParentMeetingRecord(
      id: 'pm_${_meetings.length + 1}',
      studentId: studentId,
      studentName: studentName,
      parentName: parentName,
      teacherName: teacherName,
      meetingAt: meetingAt,
      notes: notes,
      actionItems: const [],
      followUps: const [],
      lastUpdatedAt: DateTime.now(),
    );
    _meetings.insert(0, record);
    return record;
  }

  @override
  Future<ParentMeetingRecord> saveNotes({
    required RepositoryQuery query,
    required String meetingId,
    required String notes,
  }) async {
    final index = _meetings.indexWhere((meeting) => meeting.id == meetingId);
    if (index < 0) throw StateError('Meeting not found: $meetingId');
    final updated = _meetings[index].copyWith(
      notes: notes,
      lastUpdatedAt: DateTime.now(),
    );
    _meetings[index] = updated;
    return updated;
  }

  @override
  Future<ParentMeetingRecord> saveSummary({
    required RepositoryQuery query,
    required String meetingId,
    required String summary,
  }) async {
    final index = _meetings.indexWhere((meeting) => meeting.id == meetingId);
    if (index < 0) throw StateError('Meeting not found: $meetingId');
    final updated = _meetings[index].copyWith(
      aiSummary: summary,
      lastUpdatedAt: DateTime.now(),
    );
    _meetings[index] = updated;
    return updated;
  }

  @override
  Future<ParentMeetingRecord> completeAction({
    required RepositoryQuery query,
    required String meetingId,
    required String actionItemId,
    required bool completed,
  }) async {
    final meetingIndex =
        _meetings.indexWhere((meeting) => meeting.id == meetingId);
    if (meetingIndex < 0) throw StateError('Meeting not found: $meetingId');
    final meeting = _meetings[meetingIndex];
    final updatedActions = meeting.actionItems
        .map((item) => item.id == actionItemId
            ? item.copyWith(
                completed: completed,
                completedAt: completed ? DateTime.now() : null,
              )
            : item)
        .toList(growable: false);
    final updated = meeting.copyWith(
      actionItems: updatedActions,
      lastUpdatedAt: DateTime.now(),
    );
    _meetings[meetingIndex] = updated;
    return updated;
  }

  @override
  Future<MeetingFollowUp> scheduleFollowUp({
    required RepositoryQuery query,
    required String meetingId,
    required DateTime scheduledAt,
    required String channel,
    String? notes,
  }) async {
    final meetingIndex =
        _meetings.indexWhere((meeting) => meeting.id == meetingId);
    if (meetingIndex < 0) throw StateError('Meeting not found: $meetingId');

    final followUp = MeetingFollowUp(
      id: 'fu_${DateTime.now().millisecondsSinceEpoch}',
      meetingId: meetingId,
      scheduledAt: scheduledAt,
      channel: channel,
      status: 'scheduled',
      notes: notes,
    );
    final meeting = _meetings[meetingIndex];
    _meetings[meetingIndex] = meeting.copyWith(
      followUps: [...meeting.followUps, followUp],
      lastUpdatedAt: DateTime.now(),
    );
    return followUp;
  }
}
