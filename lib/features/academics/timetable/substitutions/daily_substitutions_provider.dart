import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/timetable/daily_timetable_engine.dart';
import '../../../../core/timetable/mock_daily_timetable_store.dart';
import '../../../hr/hr_providers.dart';

/// Bumped after an override so the screen rebuilds.
final dailyTimetableTickProvider = StateProvider<int>((ref) => 0);

/// The day being viewed (defaults to today). The base timetable is fixed; only
/// the substitutions change per date, driven by approved leave.
final selectedTimetableDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Teachers on approved leave for the selected date (read-only — comes from HR
/// leave approvals, not manual marking).
final teachersOnLeaveForSelectedDateProvider = Provider<Set<String>>((ref) {
  final date = ref.watch(selectedTimetableDateProvider);
  final leave = ref.watch(hrLeaveProvider);
  return teachersOnLeaveForDate(leave?.requests ?? const [], date);
});

/// Today's resolved (auto-substituted) grid for the selected date.
final dailySubstitutionGridProvider = Provider<List<ScheduledPeriod>>((ref) {
  ref.watch(dailyTimetableTickProvider);
  final onLeave = ref.watch(teachersOnLeaveForSelectedDateProvider);
  MockDailyTimetableStore.instance.applyLeave(onLeave);
  return MockDailyTimetableStore.instance.resolved();
});

void stepSelectedDate(WidgetRef ref, int days) {
  ref.read(selectedTimetableDateProvider.notifier).update(
        (d) => d.add(Duration(days: days)),
      );
}

void overrideSubstitution(
  WidgetRef ref, {
  required String periodId,
  required String classLabel,
  required TimetableTeacher teacher,
}) {
  MockDailyTimetableStore.instance.overrideAssignment(
    periodId: periodId,
    classLabel: classLabel,
    teacher: teacher,
  );
  ref.read(dailyTimetableTickProvider.notifier).state++;
}
