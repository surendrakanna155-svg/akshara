import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'leave_models.dart';

/// Active section tab on PA-12.
final parentLeaveSectionProvider = StateProvider<LeaveScreenSection>(
  (ref) => LeaveScreenSection.history,
);

/// Apply-leave draft form.
final leaveApplyDraftProvider = StateProvider<LeaveApplyDraft>(
  (ref) => const LeaveApplyDraft(),
);

final parentLeaveLoadingProvider = StateProvider<bool>((ref) => false);
final parentLeaveErrorProvider = StateProvider<bool>((ref) => false);
final parentLeaveEmptyProvider = StateProvider<bool>((ref) => false);
final parentLeaveSubmittingProvider = StateProvider<bool>((ref) => false);

final parentLeaveHistoryFutureProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  return ref.read(parentRepositoryProvider).getLeaveHistory(query: ref.watch(repositoryQueryProvider));
});

final _parentLeaveLocalSubmissionsProvider = StateProvider<List<LeaveRequest>>(
  (ref) => const [],
);

/// Leave history list.
final parentLeaveHistoryProvider = Provider<List<LeaveRequest>>((ref) {
  if (ref.watch(parentLeaveEmptyProvider)) {
    return const [];
  }
  final local = ref.watch(_parentLeaveLocalSubmissionsProvider);
  final base = watchRepositoryFuture(
    ref,
    ref.watch(parentLeaveHistoryFutureProvider),
    manualLoading: ref.watch(parentLeaveLoadingProvider),
    manualError: ref.watch(parentLeaveErrorProvider),
    manualEmpty: ref.watch(parentLeaveEmptyProvider),
  );
  final resolved = base ?? ref.watch(parentLeaveHistoryFutureProvider).value ?? const [];
  return [...local, ...resolved];
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

  ref.read(_parentLeaveLocalSubmissionsProvider.notifier).state = [
    newRequest,
    ...ref.read(_parentLeaveLocalSubmissionsProvider),
  ];
  ref.read(leaveApplyDraftProvider.notifier).state = const LeaveApplyDraft();
  ref.read(parentLeaveSectionProvider.notifier).state =
      LeaveScreenSection.history;
  ref.read(parentLeaveSubmittingProvider.notifier).state = false;
  return true;
}
