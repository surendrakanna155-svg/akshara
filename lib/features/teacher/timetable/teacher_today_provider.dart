import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/timetable/daily_timetable_engine.dart';
import '../../../core/timetable/mock_daily_timetable_store.dart';
import '../../academics/timetable/substitutions/daily_substitutions_provider.dart';
import '../communication/teacher_teaching_context_provider.dart';

/// Today's periods for the logged-in teacher, including any class they've been
/// auto-assigned to cover. Rebuilds when the daily substitution state changes.
final teacherTodayScheduleProvider = Provider<List<ScheduledPeriod>>((ref) {
  ref.watch(dailyTimetableTickProvider);
  final ctx = ref.watch(resolvedTeacherTeachingContextProvider);
  return MockDailyTimetableStore.instance.forTeacher(ctx.teacherId);
});
