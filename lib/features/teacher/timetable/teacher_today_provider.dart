import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/timetable/daily_timetable_engine.dart';
import '../../../core/timetable/mock_daily_timetable_store.dart';
import '../../academics/timetable/substitutions/daily_substitutions_provider.dart';
import '../../academics/timetable/timetable_models.dart';
import '../communication/teacher_teaching_context_provider.dart';

/// Today's base periods for the logged-in teacher (their own class schedule).
final teacherTodayScheduleProvider = Provider<List<ScheduledPeriod>>((ref) {
  final ctx = ref.watch(resolvedTeacherTeachingContextProvider);
  return MockDailyTimetableStore.instance.forTeacher(ctx.teacherId);
});

/// TCH-4 — the real, server-resolved cover the logged-in teacher is picking up
/// for the selected date: substitutions where THEY are the substitute. Drives a
/// "Substitute" indicator so a resolved sub actually shows on the teacher's day.
final teacherTodayCoverProvider =
    Provider<AsyncValue<List<TimetableSubstitution>>>((ref) {
  final ctx = ref.watch(resolvedTeacherTeachingContextProvider);
  return ref.watch(dailySubstitutionsProvider).whenData(
        (bundle) => bundle.substitutions
            .where((s) => s.substituteTeacherId == ctx.teacherId)
            .toList(),
      );
});
