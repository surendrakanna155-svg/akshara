import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/timetable/daily_timetable_engine.dart';
import '../../../../core/timetable/mock_daily_timetable_store.dart';

/// Bumped after any change so the screen rebuilds.
final dailyTimetableTickProvider = StateProvider<int>((ref) => 0);

/// Today's resolved (auto-substituted) class grid.
final dailySubstitutionGridProvider = Provider<List<ScheduledPeriod>>((ref) {
  ref.watch(dailyTimetableTickProvider);
  return MockDailyTimetableStore.instance.resolved();
});

final teachersOnLeaveProvider = Provider<Set<String>>((ref) {
  ref.watch(dailyTimetableTickProvider);
  return MockDailyTimetableStore.instance.onLeave;
});

void setTeacherOnLeave(WidgetRef ref, String teacherId, bool isOnLeave) {
  MockDailyTimetableStore.instance.setOnLeave(teacherId, isOnLeave);
  MockDailyTimetableStore.instance.prepareToday(); // re-run substitution rules
  ref.read(dailyTimetableTickProvider.notifier).state++;
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
