import 'package:dio/dio.dart';

import '../../../../features/parent_meetings/parent_meeting_models.dart';
import '../../../../features/parent_meetings/parent_meetings_repository.dart';
import '../../repository_query.dart';
import '../admissions/dto/api_envelope_dto.dart';

/// API implementation of [ParentMeetingsRepository] for the parent PTM view
/// (MJ-C4). The parent backend exposes a read-only meeting list
/// (`GET /parent/meetings`) plus an RSVP write (`POST /parent/meetings/{id}/rsvp`).
///
/// The parent's PTM surface is read-only: it lists real `ptm_meeting` entities
/// and never fabricates meetings — an empty backend list yields an empty UI
/// (empty-state). The teacher-side management mutations declared on the shared
/// interface (create/saveNotes/saveSummary/completeAction/scheduleFollowUp) are
/// not part of the parent journey and are intentionally unsupported here, so we
/// never silently fabricate or drop a write.
class ApiParentMeetingsRepository implements ParentMeetingsRepository {
  ApiParentMeetingsRepository(this._dio);

  final Dio _dio;

  static const String _base = '/parent/meetings';

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
      ...query.additionalQueryParams,
    };
  }

  @override
  Future<List<ParentMeetingRecord>> listMeetings({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _base,
      queryParameters: _queryParams(query),
    );
    final envelope = ApiEnvelopeDto.fromJson(response.data ?? const {});
    return [
      for (final item in envelope.requireListItems()) _toMeeting(item),
    ];
  }

  /// Record the parent's RSVP against a meeting. Returns the refreshed record.
  ///
  /// Not on [ParentMeetingsRepository] (the shared interface predates the
  /// parent RSVP route); exposed for the parent PTM screen to call directly.
  Future<ParentMeetingRecord> rsvp({
    required RepositoryQuery query,
    required String meetingId,
    required String response,
    String? note,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_base/$meetingId/rsvp',
      queryParameters: _queryParams(query),
      data: {
        'response': response,
        if (note != null) 'note': note,
      },
    );
    final envelope = ApiEnvelopeDto.fromJson(res.data ?? const {});
    return _toMeeting(envelope.requireData());
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
  }) {
    throw UnsupportedError(
      'Creating a PTM meeting is a teacher-scope action, not available to parents.',
    );
  }

  @override
  Future<ParentMeetingRecord> saveNotes({
    required RepositoryQuery query,
    required String meetingId,
    required String notes,
  }) {
    throw UnsupportedError(
      'Editing PTM notes is a teacher-scope action, not available to parents.',
    );
  }

  @override
  Future<ParentMeetingRecord> saveSummary({
    required RepositoryQuery query,
    required String meetingId,
    required String summary,
  }) {
    throw UnsupportedError(
      'Editing the PTM summary is a teacher-scope action, not available to parents.',
    );
  }

  @override
  Future<ParentMeetingRecord> completeAction({
    required RepositoryQuery query,
    required String meetingId,
    required String actionItemId,
    required bool completed,
  }) {
    throw UnsupportedError(
      'Completing a PTM action item is a teacher-scope action, not available to parents.',
    );
  }

  @override
  Future<MeetingFollowUp> scheduleFollowUp({
    required RepositoryQuery query,
    required String meetingId,
    required DateTime scheduledAt,
    required String channel,
    String? notes,
  }) {
    throw UnsupportedError(
      'Scheduling a PTM follow-up is a teacher-scope action, not available to parents.',
    );
  }

  ParentMeetingRecord _toMeeting(Map<String, dynamic> raw) {
    return ParentMeetingRecord(
      id: raw['id'] as String? ?? '',
      studentId:
          raw['studentId'] as String? ?? raw['sisStudentId'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      parentName: raw['parentName'] as String? ?? '',
      teacherName: raw['teacherName'] as String? ?? '',
      meetingAt:
          DateTime.tryParse(raw['meetingAt'] as String? ?? '') ?? DateTime.now(),
      notes: raw['notes'] as String? ?? '',
      aiSummary: raw['aiSummary'] as String?,
      actionItems: _toActionItems(raw['actionItems'] as List<dynamic>? ?? const []),
      followUps: _toFollowUps(raw['followUps'] as List<dynamic>? ?? const []),
      lastUpdatedAt: DateTime.tryParse(raw['lastUpdatedAt'] as String? ?? ''),
    );
  }

  List<MeetingActionItem> _toActionItems(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          MeetingActionItem(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            owner: item['owner'] as String?,
            dueDate: DateTime.tryParse(item['dueDate'] as String? ?? ''),
            completed: item['completed'] as bool? ?? false,
            completedAt: DateTime.tryParse(item['completedAt'] as String? ?? ''),
          ),
    ];
  }

  List<MeetingFollowUp> _toFollowUps(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          MeetingFollowUp(
            id: item['id'] as String? ?? '',
            meetingId: item['meetingId'] as String? ?? '',
            scheduledAt:
                DateTime.tryParse(item['scheduledAt'] as String? ?? '') ??
                    DateTime.now(),
            channel: item['channel'] as String? ?? 'call',
            status: item['status'] as String? ?? 'scheduled',
            notes: item['notes'] as String?,
          ),
    ];
  }
}
