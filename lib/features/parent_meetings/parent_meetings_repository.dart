import '../../core/repositories/repository_query.dart';
import 'parent_meeting_models.dart';

abstract class ParentMeetingsRepository {
  Future<List<ParentMeetingRecord>> listMeetings({
    required RepositoryQuery query,
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
