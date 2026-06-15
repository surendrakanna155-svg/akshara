import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_inference_models.dart';
import '../../core/ai/ai_inference_pipeline.dart';
import '../../core/ai/ai_inference_providers.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/interfaces/communication_repository.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'parent_meeting_models.dart';
import 'parent_meetings_providers.dart';

void assertManageParentMeetings(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  final canManage = permissions != null &&
      (permissions.has(Permission.manageAcademicProgress) ||
          permissions.has(Permission.manageAcademicTimetable));
  if (!canManage) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage parent meetings.',
        code: 'RBAC_MANAGE_PARENT_MEETINGS',
      ),
    );
  }
}

void _invalidateParentMeetings(Ref ref) {
  ref.invalidate(parentMeetingsFutureProvider);
  ref.invalidate(selectedParentMeetingProvider);
}

class ParentMeetingsMutationsNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<ParentMeetingRecord> createMeeting({
    required String studentId,
    required String studentName,
    required String parentName,
    required String teacherName,
    required DateTime meetingAt,
    String notes = '',
  }) async {
    state = const AsyncLoading();
    try {
      assertManageParentMeetings(ref);
      final created =
          await ref.read(parentMeetingsRepositoryProvider).createMeeting(
                query: ref.read(repositoryQueryProvider),
                studentId: studentId,
                studentName: studentName,
                parentName: parentName,
                teacherName: teacherName,
                meetingAt: meetingAt,
                notes: notes,
              );
      _invalidateParentMeetings(ref);
      ref.read(selectedParentMeetingIdProvider.notifier).state = created.id;
      state = const AsyncData(null);
      return created;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<ParentMeetingRecord> saveNotes({
    required String meetingId,
    required String notes,
  }) async {
    state = const AsyncLoading();
    try {
      assertManageParentMeetings(ref);
      final updated =
          await ref.read(parentMeetingsRepositoryProvider).saveNotes(
                query: ref.read(repositoryQueryProvider),
                meetingId: meetingId,
                notes: notes,
              );
      _invalidateParentMeetings(ref);
      state = const AsyncData(null);
      return updated;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      throw ApiFailureException(apiFailureMapper.fromException(error));
    }
  }

  Future<ParentMeetingRecord> generateSummary({
    required ParentMeetingRecord meeting,
  }) async {
    state = const AsyncLoading();
    try {
      assertManageParentMeetings(ref);
      final pipeline = ref.read(aiInferencePipelineProvider);
      final response = await pipeline.complete(
        AiInferenceRequest(
          prompt:
              'Summarize this parent meeting. Student: ${meeting.studentName}, Parent: ${meeting.parentName}, Teacher: ${meeting.teacherName}. Notes: ${meeting.notes}',
          taskType: aiTaskTypeName(AiInferenceTaskType.parentMeetingSummary),
          systemPrompt:
              'You summarize school parent meetings into concise actionable summaries.',
          context: {
            'meetingId': meeting.id,
            'studentId': meeting.studentId,
            'meetingAt': meeting.meetingAt.toIso8601String(),
          },
        ),
      );
      final updated =
          await ref.read(parentMeetingsRepositoryProvider).saveSummary(
                query: ref.read(repositoryQueryProvider),
                meetingId: meeting.id,
                summary: response.content,
              );
      _invalidateParentMeetings(ref);
      state = const AsyncData(null);
      return updated;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      throw ApiFailureException(apiFailureMapper.fromException(error));
    }
  }

  Future<ParentMeetingRecord> completeAction({
    required String meetingId,
    required String actionItemId,
    required bool completed,
  }) async {
    state = const AsyncLoading();
    try {
      assertManageParentMeetings(ref);
      final updated =
          await ref.read(parentMeetingsRepositoryProvider).completeAction(
                query: ref.read(repositoryQueryProvider),
                meetingId: meetingId,
                actionItemId: actionItemId,
                completed: completed,
              );
      _invalidateParentMeetings(ref);
      state = const AsyncData(null);
      return updated;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      throw ApiFailureException(apiFailureMapper.fromException(error));
    }
  }

  Future<MeetingFollowUp> scheduleFollowUp({
    required String meetingId,
    required DateTime scheduledAt,
    required String channel,
    String? notes,
    bool notifyParent = false,
  }) async {
    state = const AsyncLoading();
    try {
      assertManageParentMeetings(ref);
      final query = ref.read(repositoryQueryProvider);
      final followUp =
          await ref.read(parentMeetingsRepositoryProvider).scheduleFollowUp(
                query: query,
                meetingId: meetingId,
                scheduledAt: scheduledAt,
                channel: channel,
                notes: notes,
              );
      if (notifyParent) {
        await ref.read(communicationRepositoryProvider).sendBroadcast(
              query: query,
              request: BroadcastRequest(
                audience: 'meeting_$meetingId',
                title: 'Parent meeting follow-up scheduled',
                body: notes ??
                    'A follow-up has been scheduled for ${scheduledAt.toLocal()}.',
              ),
            );
      }
      _invalidateParentMeetings(ref);
      state = const AsyncData(null);
      return followUp;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      throw ApiFailureException(apiFailureMapper.fromException(error));
    }
  }
}

final parentMeetingsMutationsProvider =
    AsyncNotifierProvider<ParentMeetingsMutationsNotifier, void>(
  ParentMeetingsMutationsNotifier.new,
);
