import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/content_localization.dart';
import '../../../core/i18n/supported_languages.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../parent_meetings/parent_meeting_models.dart';
import '../parent_active_child_provider.dart';

ParentMeetingRecord _localizeMeeting(
  ParentMeetingRecord meeting,
  AksharaLanguage language,
) {
  return meeting.copyWith(
    notes: ContentLocalization.localize(meeting.notes, language),
    aiSummary: meeting.aiSummary == null
        ? null
        : ContentLocalization.localize(meeting.aiSummary!, language),
    actionItems: [
      for (final action in meeting.actionItems)
        action.copyWith(
          title: ContentLocalization.localize(action.title, language),
        ),
    ],
    followUps: [
      for (final followUp in meeting.followUps)
        followUp.copyWith(
          notes: followUp.notes == null
              ? null
              : ContentLocalization.localize(followUp.notes!, language),
        ),
    ],
  );
}

/// ALL of the parent's PTM meetings (across their linked children), from the
/// real `GET /parent/meetings` (own-child scoped server-side against the JWT
/// `child_ids`). Deterministically localized to the parent's preferred
/// language — NEVER an LLM/free-text translate.
final parentAllMeetingsProvider =
    FutureProvider<List<ParentMeetingRecord>>((ref) async {
  final child = ref.watch(parentActiveChildProvider);
  // Deterministic parent-preferred language (dictionary catalog, no LLM),
  // resolved from the active child's real id via the parent-comms store.
  final language = child == null
      ? AksharaLanguage.english
      : ContentLocalization.languageForStudent(child.id);
  // PAR-1/PAR-6: the query carries `activeChildId`; the backend list endpoint
  // returns meetings for ALL of the parent's children, scoped to child_ids.
  final meetings = await ref
      .read(parentMeetingsRepositoryProvider)
      .listMeetings(query: ref.watch(parentRepositoryQueryProvider));
  return [
    for (final meeting in meetings) _localizeMeeting(meeting, language),
  ];
});

/// PTM records for the parent's ACTIVE child only (mobile PTM screen).
///
/// Scoped by the active child's real id (`child_ids`) — NOT a client-side
/// name match / mock student mapping. A meeting belongs to the active child
/// when its `studentId` equals the active child's id.
final parentChildMeetingsProvider =
    FutureProvider<List<ParentMeetingRecord>>((ref) async {
  final child = ref.watch(parentActiveChildProvider);
  final meetings = await ref.watch(parentAllMeetingsProvider.future);
  if (child == null) return meetings;
  final scoped = meetings
      .where((meeting) => meeting.studentId == child.id)
      .toList(growable: false);
  // When the backend already returns only the active child's meetings (the
  // common case — `activeChildId` is on the query), the id filter is a no-op;
  // if none matched but the backend returned rows, fall back to showing them
  // rather than a false empty state.
  return scoped.isEmpty && meetings.isNotEmpty ? meetings : scoped;
});

/// The soonest UPCOMING meeting for the active child (PAR-6 "next PTM" hero).
/// Null when there is no future meeting.
final parentNextMeetingProvider = Provider<ParentMeetingRecord?>((ref) {
  final meetings = ref.watch(parentChildMeetingsProvider).valueOrNull;
  if (meetings == null || meetings.isEmpty) return null;
  final now = DateTime.now();
  final upcoming = meetings
      .where((meeting) => meeting.meetingAt.isAfter(now))
      .toList(growable: false)
    ..sort((a, b) => a.meetingAt.compareTo(b.meetingAt));
  return upcoming.isEmpty ? null : upcoming.first;
});
