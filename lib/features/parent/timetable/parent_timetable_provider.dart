import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'timetable_models.dart';

/// Selected day tab id in the Monday-Friday strip.
final parentTimetableSelectedDayProvider = StateProvider<String>((ref) => 'wed');

final parentTimetableLoadingProvider = StateProvider<bool>((ref) => false);
final parentTimetableErrorProvider = StateProvider<bool>((ref) => false);
final parentTimetableEmptyProvider = StateProvider<bool>((ref) => false);

final parentTimetableFutureProvider = FutureProvider<ParentTimetableData>((ref) async {
  return ref.read(parentRepositoryProvider).getTimetable(query: ref.watch(repositoryQueryProvider));
});

final parentTimetableProvider = Provider<ParentTimetableData>((ref) {
  final selectedDayId = ref.watch(parentTimetableSelectedDayProvider);
  final isEmpty = ref.watch(parentTimetableEmptyProvider);
  final base = watchRepositoryFuture(
    ref,
    ref.watch(parentTimetableFutureProvider),
    manualLoading: ref.watch(parentTimetableLoadingProvider),
    manualError: ref.watch(parentTimetableErrorProvider),
    manualEmpty: ref.watch(parentTimetableEmptyProvider),
  );
  final resolved = base ?? ref.watch(parentTimetableFutureProvider).value;
  if (resolved == null) {
    return const ParentTimetableData(
      childName: 'Ravi Kumar',
      childClass: '8-A',
      weekRangeLabel: '1 Jun - 5 Jun 2026',
      days: [],
      totalPeriodsThisWeek: 0,
      completedPeriodsToday: 0,
      upcomingPeriodsToday: 0,
      unreadNotifications: 2,
    ).withSelectedDay(selectedDayId);
  }
  final data = isEmpty
      ? ParentTimetableData(
          childName: resolved.childName,
          childClass: resolved.childClass,
          weekRangeLabel: resolved.weekRangeLabel,
          days: const [],
          totalPeriodsThisWeek: 0,
          completedPeriodsToday: 0,
          upcomingPeriodsToday: 0,
          unreadNotifications: resolved.unreadNotifications,
        )
      : resolved;
  return data.withSelectedDay(selectedDayId);
});
