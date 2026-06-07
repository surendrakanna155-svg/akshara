import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../parent_mutations_provider.dart';
import '../parent_requests.dart';
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

/// Leave history list.
final parentLeaveHistoryProvider = Provider<List<LeaveRequest>>((ref) {
  if (ref.watch(parentLeaveEmptyProvider)) {
    return const [];
  }
  final base = watchRepositoryFuture(
    ref,
    ref.watch(parentLeaveHistoryFutureProvider),
    manualLoading: ref.watch(parentLeaveLoadingProvider),
    manualError: ref.watch(parentLeaveErrorProvider),
    manualEmpty: ref.watch(parentLeaveEmptyProvider),
  );
  return base ?? ref.watch(parentLeaveHistoryFutureProvider).value ?? const [];
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

  final result = await ref.read(submitParentLeaveProvider.notifier).execute(
        ParentLeaveSubmitRequest(
          childId: 'child_ravi',
          fromDateLabel: draft.fromDateLabel,
          toDateLabel: draft.toDateLabel,
          reason: draft.reason.trim(),
          type: draft.type,
          hasAttachment: draft.hasAttachment,
          attachmentName: draft.attachmentName,
        ),
      );

  ref.read(parentLeaveSubmittingProvider.notifier).state = false;

  if (result == null) {
    return false;
  }

  ref.read(leaveApplyDraftProvider.notifier).state = const LeaveApplyDraft();
  ref.read(parentLeaveSectionProvider.notifier).state =
      LeaveScreenSection.history;
  return true;
}
