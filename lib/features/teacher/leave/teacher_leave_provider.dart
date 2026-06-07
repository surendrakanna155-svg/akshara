import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
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

final teacherLeaveHistoryFutureProvider =
    FutureProvider<List<TeacherLeaveRequest>>((ref) async {
  return ref.read(teacherRepositoryProvider).getLeaveHistory(
        query: ref.watch(repositoryQueryProvider),
      );
});

final _teacherLeaveLocalSubmissionsProvider = StateProvider<List<TeacherLeaveRequest>>(
  (ref) => const [],
);

final teacherLeaveBalanceFutureProvider = FutureProvider<LeaveBalance>((ref) async {
  return ref.read(teacherRepositoryProvider).getLeaveBalance(
        query: ref.watch(repositoryQueryProvider),
      );
});

final teacherLeaveBalanceProvider = Provider<LeaveBalance>((ref) {
  final data = watchRepositoryFuture(
    ref,
    ref.watch(teacherLeaveBalanceFutureProvider),
    manualLoading: ref.watch(teacherLeaveLoadingProvider),
    manualError: ref.watch(teacherLeaveErrorProvider),
    manualEmpty: ref.watch(teacherLeaveEmptyProvider),
  );
  return data ??
      ref.watch(teacherLeaveBalanceFutureProvider).value ??
      const LeaveBalance(
        casualRemaining: 6,
        sickRemaining: 4,
        earnedRemaining: 12,
      );
});

final teacherLeaveHistoryProvider = Provider<List<TeacherLeaveRequest>>((ref) {
  if (ref.watch(teacherLeaveEmptyProvider)) return const [];
  final local = ref.watch(_teacherLeaveLocalSubmissionsProvider);
  final base = watchRepositoryFuture(
    ref,
    ref.watch(teacherLeaveHistoryFutureProvider),
    manualLoading: ref.watch(teacherLeaveLoadingProvider),
    manualError: ref.watch(teacherLeaveErrorProvider),
    manualEmpty: ref.watch(teacherLeaveEmptyProvider),
  ) ??
      ref.watch(teacherLeaveHistoryFutureProvider).value ??
      const <TeacherLeaveRequest>[];
  return [...local, ...base];
});

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

  ref.read(_teacherLeaveLocalSubmissionsProvider.notifier).state = [
    request,
    ...ref.read(_teacherLeaveLocalSubmissionsProvider),
  ];
  ref.read(teacherLeaveApplyDraftProvider.notifier).state =
      const TeacherLeaveApplyDraft();
  ref.read(teacherLeaveSectionProvider.notifier).state =
      TeacherLeaveSection.history;
  return true;
}
