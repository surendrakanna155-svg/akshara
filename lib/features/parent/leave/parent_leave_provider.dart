import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'leave_models.dart';

/// Active section tab on PA-12.
final parentLeaveSectionProvider = StateProvider<LeaveScreenSection>(
  (ref) => LeaveScreenSection.history,
);

/// Apply-leave draft form.
final leaveApplyDraftProvider = StateProvider<LeaveApplyDraft>(
  (ref) => const LeaveApplyDraft(),
);

/// Loading flag for API integration.
final parentLeaveLoadingProvider = StateProvider<bool>((ref) => false);

/// Error flag for API integration.
final parentLeaveErrorProvider = StateProvider<bool>((ref) => false);

/// Empty history toggle.
final parentLeaveEmptyProvider = StateProvider<bool>((ref) => false);

/// Submitting leave application.
final parentLeaveSubmittingProvider = StateProvider<bool>((ref) => false);

final _parentLeaveHistoryProvider = StateProvider<List<LeaveRequest>>(
  (ref) => _mockLeaveHistory(),
);

/// Leave history list.
final parentLeaveHistoryProvider = Provider<List<LeaveRequest>>((ref) {
  if (ref.watch(parentLeaveEmptyProvider)) {
    return const [];
  }
  return ref.watch(_parentLeaveHistoryProvider);
});

/// Screen payload.
final parentLeaveDataProvider = Provider<ParentLeaveData>((ref) {
  final history = ref.watch(parentLeaveHistoryProvider);
  return ParentLeaveData(
    childName: 'Ravi Kumar',
    childClass: '8-A',
    history: history,
    unreadNotifications: 2,
    pendingCount: history
        .where((item) => item.status == LeaveStatus.pending)
        .length,
  );
});

class ParentLeaveData {
  const ParentLeaveData({
    required this.childName,
    required this.childClass,
    required this.history,
    required this.unreadNotifications,
    required this.pendingCount,
  });

  final String childName;
  final String childClass;
  final List<LeaveRequest> history;
  final int unreadNotifications;
  final int pendingCount;
}

List<LeaveRequest> _mockLeaveHistory() {
  return const [
    LeaveRequest(
      id: 'lv_1',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      fromDateLabel: '10 Jun 2026',
      toDateLabel: '10 Jun 2026',
      reason: 'Fever and doctor advised rest for one day.',
      type: LeaveType.sick,
      status: LeaveStatus.pending,
      submittedLabel: 'Submitted 5 Jun 2026',
      hasAttachment: true,
      attachmentName: 'medical_note.pdf',
      timeline: [
        LeaveTimelineStep(
          label: 'Submitted',
          dateLabel: '5 Jun 2026 · 9:10 AM',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'Class teacher review',
          dateLabel: 'Expected by 6 Jun',
          isComplete: false,
        ),
        LeaveTimelineStep(
          label: 'School approval',
          dateLabel: 'Pending',
          isComplete: false,
        ),
      ],
    ),
    LeaveRequest(
      id: 'lv_2',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      fromDateLabel: '18 May 2026',
      toDateLabel: '19 May 2026',
      reason: 'Family wedding out of town.',
      type: LeaveType.family,
      status: LeaveStatus.approved,
      submittedLabel: 'Submitted 15 May 2026',
      timeline: [
        LeaveTimelineStep(
          label: 'Submitted',
          dateLabel: '15 May 2026 · 6:40 PM',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'Class teacher review',
          dateLabel: '16 May 2026 · Approved',
          isComplete: true,
          note: 'Reviewed by Arun Sir',
        ),
        LeaveTimelineStep(
          label: 'School approval',
          dateLabel: '16 May 2026 · Approved',
          isComplete: true,
        ),
      ],
    ),
    LeaveRequest(
      id: 'lv_3',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      fromDateLabel: '2 Apr 2026',
      toDateLabel: '2 Apr 2026',
      reason: 'Travel plan overlapped with school day.',
      type: LeaveType.personal,
      status: LeaveStatus.rejected,
      submittedLabel: 'Submitted 1 Apr 2026',
      timeline: [
        LeaveTimelineStep(
          label: 'Submitted',
          dateLabel: '1 Apr 2026 · 8:05 AM',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'Class teacher review',
          dateLabel: '1 Apr 2026 · Rejected',
          isComplete: true,
          note: 'Exam day — leave not permitted',
        ),
        LeaveTimelineStep(
          label: 'School approval',
          dateLabel: 'Not required',
          isComplete: false,
        ),
      ],
    ),
  ];
}

Future<bool> submitLeaveApplication(WidgetRef ref) async {
  final draft = ref.read(leaveApplyDraftProvider);
  if (!draft.isValid) {
    return false;
  }

  ref.read(parentLeaveSubmittingProvider.notifier).state = true;
  await Future<void>.delayed(const Duration(milliseconds: 900));

  final newRequest = LeaveRequest(
    id: 'lv_new_${DateTime.now().millisecondsSinceEpoch}',
    childName: 'Ravi Kumar',
    childClass: '8-A',
    fromDateLabel: draft.fromDateLabel,
    toDateLabel: draft.toDateLabel,
    reason: draft.reason.trim(),
    type: draft.type,
    status: LeaveStatus.pending,
    submittedLabel: 'Submitted just now',
    hasAttachment: draft.hasAttachment,
    attachmentName: draft.attachmentName,
    timeline: const [
      LeaveTimelineStep(
        label: 'Submitted',
        dateLabel: 'Just now',
        isComplete: true,
      ),
      LeaveTimelineStep(
        label: 'Class teacher review',
        dateLabel: 'Pending',
        isComplete: false,
      ),
      LeaveTimelineStep(
        label: 'School approval',
        dateLabel: 'Pending',
        isComplete: false,
      ),
    ],
  );

  ref.read(_parentLeaveHistoryProvider.notifier).state = [
    newRequest,
    ...ref.read(_parentLeaveHistoryProvider),
  ];
  ref.read(leaveApplyDraftProvider.notifier).state = const LeaveApplyDraft();
  ref.read(parentLeaveSectionProvider.notifier).state =
      LeaveScreenSection.history;
  ref.read(parentLeaveSubmittingProvider.notifier).state = false;
  return true;
}
