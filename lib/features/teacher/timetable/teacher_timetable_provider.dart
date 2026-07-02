import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../teacher_unread_provider.dart';
import 'timetable_models.dart';

final teacherTimetableDayProvider = StateProvider<String>((ref) => 'fri');
final teacherTimetableLoadingProvider = StateProvider<bool>((ref) => false);
final teacherTimetableErrorProvider = StateProvider<bool>((ref) => false);
final teacherTimetableEmptyProvider = StateProvider<bool>((ref) => false);

final teacherTimetableFutureProvider = FutureProvider<TeacherTimetableData>((ref) async {
  return ref.read(teacherRepositoryProvider).getTimetable(query: ref.watch(repositoryQueryProvider));
});

final teacherTimetableProvider = Provider<TeacherTimetableData>((ref) {
  final unread = ref.watch(teacherUnreadNotificationsProvider);
  if (ref.watch(teacherTimetableEmptyProvider)) {
    return TeacherTimetableData(
      teacherName: 'Priya Sharma',
      weekRangeLabel: '1 Jun - 5 Jun 2026',
      days: const [],
      unreadNotifications: unread,
    );
  }

  final selected = ref.watch(teacherTimetableDayProvider);
  final base = watchRepositoryFuture(
    ref,
    ref.watch(teacherTimetableFutureProvider),
    manualLoading: ref.watch(teacherTimetableLoadingProvider),
    manualError: ref.watch(teacherTimetableErrorProvider),
    manualEmpty: ref.watch(teacherTimetableEmptyProvider),
  ) ??
      ref.watch(teacherTimetableFutureProvider).value ??
      const TeacherTimetableData(
        teacherName: 'Priya Sharma',
        weekRangeLabel: '1 Jun - 5 Jun 2026',
        days: [],
        unreadNotifications: 0,
      );

  final days = base.days
      .map((d) => d.copyWith(isSelected: d.id == selected))
      .toList(growable: false);

  return TeacherTimetableData(
    teacherName: base.teacherName,
    weekRangeLabel: base.weekRangeLabel,
    days: days,
    unreadNotifications: unread,
  );
});
