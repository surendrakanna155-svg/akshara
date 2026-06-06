import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/semantic_status.dart';
import 'timetable_models.dart';

final teacherTimetableDayProvider = StateProvider<String>((ref) => 'fri');
final teacherTimetableLoadingProvider = StateProvider<bool>((ref) => false);
final teacherTimetableErrorProvider = StateProvider<bool>((ref) => false);
final teacherTimetableEmptyProvider = StateProvider<bool>((ref) => false);

final teacherTimetableProvider = Provider<TeacherTimetableData>((ref) {
  if (ref.watch(teacherTimetableEmptyProvider)) {
    return const TeacherTimetableData(
      teacherName: 'Priya Sharma',
      weekRangeLabel: '1 Jun - 5 Jun 2026',
      days: [],
      unreadNotifications: 1,
    );
  }

  final selected = ref.watch(teacherTimetableDayProvider);
  final days = _mockDays()
      .map((d) => d.copyWith(isSelected: d.id == selected))
      .toList(growable: false);

  return TeacherTimetableData(
    teacherName: 'Priya Sharma',
    weekRangeLabel: '1 Jun - 5 Jun 2026',
    days: days,
    unreadNotifications: 1,
  );
});

List<TeacherTimetableDay> _mockDays() {
  return const [
    TeacherTimetableDay(
      id: 'mon',
      shortLabel: 'Mon',
      fullLabel: 'Monday',
      periods: [
        TeacherTimetablePeriod(
          id: 'mon-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'Mathematics',
          classLabel: '8-A',
          roomLabel: 'Room 204',
          status: ClassScheduleStatus.done,
        ),
      ],
    ),
    TeacherTimetableDay(
      id: 'fri',
      shortLabel: 'Fri',
      fullLabel: 'Friday',
      isToday: true,
      periods: [
        TeacherTimetablePeriod(
          id: 'fri-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'Mathematics',
          classLabel: '8-A',
          roomLabel: 'Room 204',
          status: ClassScheduleStatus.done,
        ),
        TeacherTimetablePeriod(
          id: 'fri-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'Mathematics',
          classLabel: '9-B',
          roomLabel: 'Room 206',
          status: ClassScheduleStatus.now,
        ),
        TeacherTimetablePeriod(
          id: 'fri-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 13:15',
          subject: 'Mathematics',
          classLabel: '8-A',
          roomLabel: 'Room 204',
          status: ClassScheduleStatus.upcoming,
        ),
      ],
    ),
  ];
}
