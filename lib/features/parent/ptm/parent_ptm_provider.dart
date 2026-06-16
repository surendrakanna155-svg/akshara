import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/communication/parent_communication_store.dart';
import '../../../core/i18n/content_localization.dart';
import '../../../core/i18n/supported_languages.dart';
import '../../../core/repositories/mock/mock_canonical_student_registry.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
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

/// PTM records for the parent's active child (mobile read-only view).
final parentChildMeetingsProvider =
    FutureProvider<List<ParentMeetingRecord>>((ref) async {
  final child = ref.watch(parentActiveChildProvider);
  final profileChildId = child != null
      ? (kAuthChildToProfileId[child.id] ?? child.id)
      : 'child_ravi';
  final canonical = MockCanonicalStudentRegistry.byParentChildId(profileChildId) ??
      MockCanonicalStudentRegistry.primaryMobileStudent;

  final language = ParentCommunicationStore.instance.preferredLanguageForStudent(
    canonical.sisStudentId,
  );

  final meetings = await ref
      .read(parentMeetingsRepositoryProvider)
      .listMeetings(query: ref.watch(repositoryQueryProvider));

  return meetings
      .where(
        (meeting) =>
            meeting.studentName == canonical.studentName ||
            meeting.studentId == canonical.sisStudentId,
      )
      .map((meeting) => _localizeMeeting(meeting, language))
      .toList(growable: false);
});
