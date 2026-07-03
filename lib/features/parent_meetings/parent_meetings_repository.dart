import '../../core/repositories/repository_query.dart';
import 'parent_meeting_models.dart';

abstract class ParentMeetingsRepository {
  Future<List<ParentMeetingRecord>> listMeetings({
    required RepositoryQuery query,
  });

  /// PAR-1 — record the active parent's RSVP against a meeting for one of their
  /// OWN children (own-child scope is enforced server-side against the JWT
  /// `child_ids`). Returns the refreshed meeting reflecting the recorded RSVP.
  Future<ParentMeetingRecord> rsvpMeeting({
    required RepositoryQuery query,
    required String meetingId,
    required MeetingRsvpResponse response,
    String? note,
  });

  Future<ParentMeetingRecord> createMeeting({
    required RepositoryQuery query,
    required String studentId,
    required String studentName,
    required String parentName,
    required String teacherName,
    required DateTime meetingAt,
    String notes,
  });

  Future<ParentMeetingRecord> saveNotes({
    required RepositoryQuery query,
    required String meetingId,
    required String notes,
  });

  Future<ParentMeetingRecord> saveSummary({
    required RepositoryQuery query,
    required String meetingId,
    required String summary,
  });

  Future<ParentMeetingRecord> completeAction({
    required RepositoryQuery query,
    required String meetingId,
    required String actionItemId,
    required bool completed,
  });

  Future<MeetingFollowUp> scheduleFollowUp({
    required RepositoryQuery query,
    required String meetingId,
    required DateTime scheduledAt,
    required String channel,
    String? notes,
  });
}
