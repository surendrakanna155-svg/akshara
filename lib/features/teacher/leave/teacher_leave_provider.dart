import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'leave_models.dart';

final teacherLeaveSectionProvider = StateProvider<TeacherLeaveSection>(
  (ref) => TeacherLeaveSection.history,
);

final teacherLeaveApplyDraftProvider = StateProvider<TeacherLeaveApplyDraft>(
  (ref) => const TeacherLeaveApplyDraft(),
);

final teacherLeaveLoadingProvider = StateProvider<bool>((ref) => false);
final teacherLeaveErrorProvider = StateProvider<bool>((ref) => false);
final teacherLeaveEmptyProvider = StateProvider<bool>((ref) => false);

final _teacherLeaveHistoryProvider = StateProvider<List<TeacherLeaveRequest>>(
  (ref) => _mockHistory(),
);

final teacherLeaveBalanceProvider = Provider<LeaveBalance>(
  (ref) => const LeaveBalance(
    casualRemaining: 6,
    sickRemaining: 4,
    earnedRemaining: 12,
  ),
);

final teacherLeaveHistoryProvider = Provider<List<TeacherLeaveRequest>>((ref) {
  if (ref.watch(teacherLeaveEmptyProvider)) return const [];
  return ref.watch(_teacherLeaveHistoryProvider);
});

List<TeacherLeaveRequest> _mockHistory() {
  return const [
    TeacherLeaveRequest(
      id: 'tlv_1',
      typeLabel: 'Casual leave',
      fromDateLabel: '18 Jun 2026',
      toDateLabel: '18 Jun 2026',
      reason: 'Personal appointment in the afternoon.',
      status: TeacherLeaveStatus.pending,
      timeline: [
        LeaveTimelineStep(
          label: 'Submitted',
          dateLabel: '5 Jun 2026',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'HOD approval',
          dateLabel: 'Pending',
          isComplete: false,
        ),
        LeaveTimelineStep(
          label: 'HR confirmation',
          dateLabel: 'Pending',
          isComplete: false,
        ),
      ],
    ),
    TeacherLeaveRequest(
      id: 'tlv_2',
      typeLabel: 'Sick leave',
      fromDateLabel: '2 May 2026',
      toDateLabel: '3 May 2026',
      reason: 'Fever and medical rest.',
      status: TeacherLeaveStatus.approved,
      timeline: [
        LeaveTimelineStep(
          label: 'Submitted',
          dateLabel: '1 May 2026',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'HOD approval',
          dateLabel: '1 May 2026',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'HR confirmation',
          dateLabel: '2 May 2026',
          isComplete: true,
        ),
      ],
    ),
  ];
}

bool submitTeacherLeave(WidgetRef ref) {
  final draft = ref.read(teacherLeaveApplyDraftProvider);
  if (!draft.isValid) return false;

  final request = TeacherLeaveRequest(
    id: 'tlv_${DateTime.now().millisecondsSinceEpoch}',
    typeLabel: draft.typeLabel,
    fromDateLabel: draft.fromDateLabel,
    toDateLabel: draft.toDateLabel,
    reason: draft.reason.trim(),
    status: TeacherLeaveStatus.pending,
    timeline: const [
      LeaveTimelineStep(
        label: 'Submitted',
        dateLabel: 'Just now',
        isComplete: true,
      ),
      LeaveTimelineStep(
        label: 'HOD approval',
        dateLabel: 'Pending',
        isComplete: false,
      ),
      LeaveTimelineStep(
        label: 'HR confirmation',
        dateLabel: 'Pending',
        isComplete: false,
      ),
    ],
  );

  ref.read(_teacherLeaveHistoryProvider.notifier).state = [
    request,
    ...ref.read(_teacherLeaveHistoryProvider),
  ];
  ref.read(teacherLeaveApplyDraftProvider.notifier).state =
      const TeacherLeaveApplyDraft();
  ref.read(teacherLeaveSectionProvider.notifier).state =
      TeacherLeaveSection.history;
  return true;
}
