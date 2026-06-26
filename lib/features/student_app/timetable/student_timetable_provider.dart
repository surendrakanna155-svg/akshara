import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../parent/timetable/timetable_models.dart';

final studentTimetableSelectedDayProvider = StateProvider<String>(
  (ref) => 'fri',
);

final studentTimetableLoadingProvider = StateProvider<bool>((ref) => false);
final studentTimetableErrorProvider = StateProvider<bool>((ref) => false);
final studentTimetableEmptyProvider = StateProvider<bool>((ref) => false);

final studentTimetableFutureProvider = FutureProvider<ParentTimetableData>((ref) async {
  return ref.read(studentRepositoryProvider).getTimetable(query: ref.watch(repositoryQueryProvider));
});

final studentTimetableProvider = Provider<ParentTimetableData>((ref) {
  final selectedDayId = ref.watch(studentTimetableSelectedDayProvider);
  final isEmpty = ref.watch(studentTimetableEmptyProvider);
  final base = watchRepositoryFuture(
    ref,
    ref.watch(studentTimetableFutureProvider),
    manualLoading: ref.watch(studentTimetableLoadingProvider),
    manualError: ref.watch(studentTimetableErrorProvider),
    manualEmpty: ref.watch(studentTimetableEmptyProvider),
  );
  final resolved = base ?? ref.watch(studentTimetableFutureProvider).value;
  if (resolved == null) {
    return const ParentTimetableData(
      childName: '',
      childClass: '',
      weekRangeLabel: '',
      days: [],
      totalPeriodsThisWeek: 0,
      completedPeriodsToday: 0,
      upcomingPeriodsToday: 0,
      unreadNotifications: 0,
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
