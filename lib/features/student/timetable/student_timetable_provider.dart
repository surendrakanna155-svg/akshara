import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../parent/timetable/timetable_models.dart';

final studentTimetableSelectedDayProvider = StateProvider<String>(
  (ref) => 'fri',
);

final studentTimetableLoadingProvider = StateProvider<bool>((ref) => false);
final studentTimetableErrorProvider = StateProvider<bool>((ref) => false);
final studentTimetableEmptyProvider = StateProvider<bool>((ref) => false);

final studentTimetableProvider = Provider<ParentTimetableData>((ref) {
  final selectedDayId = ref.watch(studentTimetableSelectedDayProvider);
  final isEmpty = ref.watch(studentTimetableEmptyProvider);
  final base = isEmpty ? _mockEmptyData() : _mockWeekData();
  return base.withSelectedDay(selectedDayId);
});

ParentTimetableData _mockWeekData() {
  final days = <TimetableDay>[
    TimetableDay(
      id: 'fri',
      shortLabel: 'Fri',
      fullLabel: 'Friday',
      date: DateTime(2026, 6, 5),
      isToday: true,
      periods: const [
        TimetablePeriod(
          id: 'fri-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'Mathematics',
          teacherName: 'Mrs. Sharma',
          roomLabel: 'Room 203',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'fri-p2',
          periodLabel: 'Period 2',
          timeRange: '09:20 - 10:05',
          subject: 'Science',
          teacherName: 'Mrs. Rao',
          roomLabel: 'Lab 2',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'fri-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'English',
          teacherName: 'Mr. Patel',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.now,
        ),
        TimetablePeriod(
          id: 'fri-p4',
          periodLabel: 'Period 4',
          timeRange: '11:05 - 11:50',
          subject: 'Physical Education',
          teacherName: 'Coach Singh',
          roomLabel: 'Ground',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'fri-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 13:15',
          subject: 'Hindi',
          teacherName: 'Meena Ma\'am',
          roomLabel: 'Room 201',
          status: TimetablePeriodStatus.upcoming,
        ),
      ],
    ),
    TimetableDay(
      id: 'mon',
      shortLabel: 'Mon',
      fullLabel: 'Monday',
      date: DateTime(2026, 6, 1),
      periods: const [
        TimetablePeriod(
          id: 'mon-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'English',
          teacherName: 'Mr. Patel',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.done,
        ),
      ],
    ),
  ];

  return ParentTimetableData(
    childName: 'Ravi Kumar',
    childClass: '8-A',
    weekRangeLabel: '1 Jun - 5 Jun 2026',
    days: days,
    totalPeriodsThisWeek: 6,
    completedPeriodsToday: 2,
    upcomingPeriodsToday: 2,
    unreadNotifications: 2,
    scheduleChangeMessage: 'Period 4 PE moved to the main ground today.',
  );
}

ParentTimetableData _mockEmptyData() {
  return const ParentTimetableData(
    childName: 'Ravi Kumar',
    childClass: '8-A',
    weekRangeLabel: '1 Jun - 5 Jun 2026',
    days: [],
    totalPeriodsThisWeek: 0,
    completedPeriodsToday: 0,
    upcomingPeriodsToday: 0,
    unreadNotifications: 2,
  );
}
