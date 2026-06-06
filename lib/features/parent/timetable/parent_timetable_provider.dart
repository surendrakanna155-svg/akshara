import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'timetable_models.dart';

/// Selected day tab id in the Monday-Friday strip.
final parentTimetableSelectedDayProvider = StateProvider<String>((ref) => 'wed');

/// Loading flag reserved for PA-04 API integration.
final parentTimetableLoadingProvider = StateProvider<bool>((ref) => false);

/// Error flag reserved for recoverable API failures.
final parentTimetableErrorProvider = StateProvider<bool>((ref) => false);

/// Empty flag to simulate no timetable records.
final parentTimetableEmptyProvider = StateProvider<bool>((ref) => false);

/// Parent timetable payload for Ravi Kumar (8-A).
final parentTimetableProvider = Provider<ParentTimetableData>((ref) {
  final selectedDayId = ref.watch(parentTimetableSelectedDayProvider);
  final isEmpty = ref.watch(parentTimetableEmptyProvider);

  final base = isEmpty ? _mockEmptyData() : _mockWeekData();
  return base.withSelectedDay(selectedDayId);
});

ParentTimetableData _mockWeekData() {
  final days = <TimetableDay>[
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
          teacherName: 'Priya Ma\'am',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'mon-p2',
          periodLabel: 'Period 2',
          timeRange: '09:20 - 10:05',
          subject: 'Mathematics',
          teacherName: 'Arun Sir',
          roomLabel: 'Room 203',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'mon-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'Science',
          teacherName: 'Nisha Ma\'am',
          roomLabel: 'Lab 2',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'mon-p4',
          periodLabel: 'Period 4',
          timeRange: '11:05 - 11:50',
          subject: 'Hindi',
          teacherName: 'Meena Ma\'am',
          roomLabel: 'Room 201',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'mon-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 01:15',
          subject: 'Social Science',
          teacherName: 'Rakesh Sir',
          roomLabel: 'Room 208',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'mon-p6',
          periodLabel: 'Period 6',
          timeRange: '01:20 - 02:05',
          subject: 'Computer',
          teacherName: 'Swapna Ma\'am',
          roomLabel: 'ICT Lab',
          status: TimetablePeriodStatus.done,
        ),
      ],
    ),
    TimetableDay(
      id: 'tue',
      shortLabel: 'Tue',
      fullLabel: 'Tuesday',
      date: DateTime(2026, 6, 2),
      periods: const [
        TimetablePeriod(
          id: 'tue-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'Mathematics',
          teacherName: 'Arun Sir',
          roomLabel: 'Room 203',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'tue-p2',
          periodLabel: 'Period 2',
          timeRange: '09:20 - 10:05',
          subject: 'English',
          teacherName: 'Priya Ma\'am',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'tue-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'Kannada',
          teacherName: 'Suma Ma\'am',
          roomLabel: 'Room 205',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'tue-p4',
          periodLabel: 'Period 4',
          timeRange: '11:05 - 11:50',
          subject: 'Science',
          teacherName: 'Nisha Ma\'am',
          roomLabel: 'Lab 2',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'tue-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 01:15',
          subject: 'Art',
          teacherName: 'Anita Ma\'am',
          roomLabel: 'Art Studio',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'tue-p6',
          periodLabel: 'Period 6',
          timeRange: '01:20 - 02:05',
          subject: 'Physical Education',
          teacherName: 'Rahul Sir',
          roomLabel: 'Ground',
          status: TimetablePeriodStatus.done,
        ),
      ],
    ),
    TimetableDay(
      id: 'wed',
      shortLabel: 'Wed',
      fullLabel: 'Wednesday',
      date: DateTime(2026, 6, 3),
      isToday: true,
      periods: const [
        TimetablePeriod(
          id: 'wed-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'Science',
          teacherName: 'Nisha Ma\'am',
          roomLabel: 'Lab 2',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'wed-p2',
          periodLabel: 'Period 2',
          timeRange: '09:20 - 10:05',
          subject: 'Mathematics',
          teacherName: 'Arun Sir',
          roomLabel: 'Room 203',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'wed-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'English',
          teacherName: 'Priya Ma\'am',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'wed-p4',
          periodLabel: 'Period 4',
          timeRange: '11:05 - 11:50',
          subject: 'Social Science',
          teacherName: 'Rakesh Sir',
          roomLabel: 'Room 205',
          status: TimetablePeriodStatus.now,
          isRoomChanged: true,
        ),
        TimetablePeriod(
          id: 'wed-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 01:15',
          subject: 'Computer',
          teacherName: 'Swapna Ma\'am',
          roomLabel: 'ICT Lab',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'wed-p6',
          periodLabel: 'Period 6',
          timeRange: '01:20 - 02:05',
          subject: 'Hindi',
          teacherName: 'Meena Ma\'am',
          roomLabel: 'Room 201',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'wed-p7',
          periodLabel: 'Period 7',
          timeRange: '02:10 - 02:50',
          subject: 'Library',
          teacherName: 'Shilpa Ma\'am',
          roomLabel: 'Library',
          status: TimetablePeriodStatus.upcoming,
        ),
      ],
    ),
    TimetableDay(
      id: 'thu',
      shortLabel: 'Thu',
      fullLabel: 'Thursday',
      date: DateTime(2026, 6, 4),
      periods: const [
        TimetablePeriod(
          id: 'thu-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'English',
          teacherName: 'Priya Ma\'am',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'thu-p2',
          periodLabel: 'Period 2',
          timeRange: '09:20 - 10:05',
          subject: 'Science',
          teacherName: 'Nisha Ma\'am',
          roomLabel: 'Lab 2',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'thu-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'Mathematics',
          teacherName: 'Arun Sir',
          roomLabel: 'Room 203',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'thu-p4',
          periodLabel: 'Period 4',
          timeRange: '11:05 - 11:50',
          subject: 'Kannada',
          teacherName: 'Suma Ma\'am',
          roomLabel: 'Room 205',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'thu-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 01:15',
          subject: 'Social Science',
          teacherName: 'Rakesh Sir',
          roomLabel: 'Room 208',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'thu-p6',
          periodLabel: 'Period 6',
          timeRange: '01:20 - 02:05',
          subject: 'Physical Education',
          teacherName: 'Rahul Sir',
          roomLabel: 'Ground',
          status: TimetablePeriodStatus.upcoming,
        ),
      ],
    ),
    TimetableDay(
      id: 'fri',
      shortLabel: 'Fri',
      fullLabel: 'Friday',
      date: DateTime(2026, 6, 5),
      periods: const [
        TimetablePeriod(
          id: 'fri-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'Mathematics',
          teacherName: 'Arun Sir',
          roomLabel: 'Room 203',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'fri-p2',
          periodLabel: 'Period 2',
          timeRange: '09:20 - 10:05',
          subject: 'Hindi',
          teacherName: 'Meena Ma\'am',
          roomLabel: 'Room 201',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'fri-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'Computer',
          teacherName: 'Swapna Ma\'am',
          roomLabel: 'ICT Lab',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'fri-p4',
          periodLabel: 'Period 4',
          timeRange: '11:05 - 11:50',
          subject: 'English',
          teacherName: 'Priya Ma\'am',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'fri-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 01:15',
          subject: 'Science',
          teacherName: 'Nisha Ma\'am',
          roomLabel: 'Lab 2',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'fri-p6',
          periodLabel: 'Period 6',
          timeRange: '01:20 - 02:05',
          subject: 'Social Science',
          teacherName: 'Rakesh Sir',
          roomLabel: 'Room 208',
          status: TimetablePeriodStatus.upcoming,
        ),
      ],
    ),
  ];

  return ParentTimetableData(
    childName: 'Ravi Kumar',
    childClass: '8-A',
    weekRangeLabel: '1 Jun - 5 Jun 2026',
    days: days,
    totalPeriodsThisWeek: days.fold<int>(
      0,
      (total, day) => total + day.periods.length,
    ),
    completedPeriodsToday: 3,
    upcomingPeriodsToday: 3,
    unreadNotifications: 2,
    scheduleChangeMessage:
        'Period 4 Social Science moved to Room 205 for today.',
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
