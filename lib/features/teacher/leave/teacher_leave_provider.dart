import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../teacher_mutations_provider.dart';
import '../teacher_requests.dart';
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
  final base = watchRepositoryFuture(
    ref,
    ref.watch(teacherLeaveHistoryFutureProvider),
    manualLoading: ref.watch(teacherLeaveLoadingProvider),
    manualError: ref.watch(teacherLeaveErrorProvider),
    manualEmpty: ref.watch(teacherLeaveEmptyProvider),
  ) ??
      ref.watch(teacherLeaveHistoryFutureProvider).value ??
      const <TeacherLeaveRequest>[];
  return base;
});

Future<bool> submitTeacherLeave(WidgetRef ref) async {
  final draft = ref.read(teacherLeaveApplyDraftProvider);
  if (!draft.isValid) return false;

  final result = await ref.read(submitTeacherLeaveProvider.notifier).execute(
        TeacherLeaveSubmitRequest(
          typeLabel: draft.typeLabel,
          fromDateLabel: draft.fromDateLabel,
          toDateLabel: draft.toDateLabel,
          reason: draft.reason.trim(),
        ),
      );

  if (result == null) return false;

  ref.read(teacherLeaveApplyDraftProvider.notifier).state =
      const TeacherLeaveApplyDraft();
  ref.read(teacherLeaveSectionProvider.notifier).state =
      TeacherLeaveSection.history;
  return true;
}
