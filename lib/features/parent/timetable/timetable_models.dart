import 'package:flutter/material.dart';

import '../../../theme/theme_extensions.dart';

/// Status of a timetable period relative to the current time.
enum TimetablePeriodStatus { done, now, upcoming }

/// Visual style resolver for [TimetablePeriodStatus].
extension TimetablePeriodStatusStyle on TimetablePeriodStatus {
  ({String label, Color background, Color foreground, IconData icon}) resolve(
    BuildContext context,
  ) {
    final colors = context.colors;
    final ext = context.akshara;

    return switch (this) {
      TimetablePeriodStatus.done => (
          label: 'Done',
          background: ext.successContainer,
          foreground: ext.success,
          icon: Icons.check_circle_outline,
        ),
      TimetablePeriodStatus.now => (
          label: 'Now',
          background: colors.primaryContainer,
          foreground: colors.primary,
          icon: Icons.play_circle_outline,
        ),
      TimetablePeriodStatus.upcoming => (
          label: 'Upcoming',
          background: colors.surfaceContainerLow,
          foreground: colors.onSurfaceVariant,
          icon: Icons.schedule_outlined,
        ),
    };
  }
}

/// Single class period in a day schedule.
@immutable
class TimetablePeriod {
  const TimetablePeriod({
    required this.id,
    required this.periodLabel,
    required this.timeRange,
    required this.subject,
    required this.teacherName,
    required this.roomLabel,
    required this.status,
    this.isRoomChanged = false,
  });

  final String id;
  final String periodLabel;
  final String timeRange;
  final String subject;
  final String teacherName;
  final String roomLabel;
  final TimetablePeriodStatus status;
  final bool isRoomChanged;
}

/// Day tab + list payload.
@immutable
class TimetableDay {
  const TimetableDay({
    required this.id,
    required this.shortLabel,
    required this.fullLabel,
    required this.date,
    required this.periods,
    this.isSelected = false,
    this.isToday = false,
  });

  final String id;
  final String shortLabel;
  final String fullLabel;
  final DateTime date;
  final List<TimetablePeriod> periods;
  final bool isSelected;
  final bool isToday;

  TimetableDay copyWith({
    String? id,
    String? shortLabel,
    String? fullLabel,
    DateTime? date,
    List<TimetablePeriod>? periods,
    bool? isSelected,
    bool? isToday,
  }) {
    return TimetableDay(
      id: id ?? this.id,
      shortLabel: shortLabel ?? this.shortLabel,
      fullLabel: fullLabel ?? this.fullLabel,
      date: date ?? this.date,
      periods: periods ?? this.periods,
      isSelected: isSelected ?? this.isSelected,
      isToday: isToday ?? this.isToday,
    );
  }
}

/// Full PA-04 timetable payload for parent screen.
@immutable
class ParentTimetableData {
  const ParentTimetableData({
    required this.childName,
    required this.childClass,
    required this.weekRangeLabel,
    required this.days,
    required this.totalPeriodsThisWeek,
    required this.completedPeriodsToday,
    required this.upcomingPeriodsToday,
    required this.unreadNotifications,
    this.scheduleChangeMessage,
  });

  final String childName;
  final String childClass;
  final String weekRangeLabel;
  final List<TimetableDay> days;
  final int totalPeriodsThisWeek;
  final int completedPeriodsToday;
  final int upcomingPeriodsToday;
  final int unreadNotifications;
  final String? scheduleChangeMessage;

  TimetableDay? get selectedDay {
    for (final day in days) {
      if (day.isSelected) {
        return day;
      }
    }
    return null;
  }

  ParentTimetableData withSelectedDay(String selectedDayId) {
    return ParentTimetableData(
      childName: childName,
      childClass: childClass,
      weekRangeLabel: weekRangeLabel,
      days: [
        for (final day in days)
          day.copyWith(
            isSelected: day.id == selectedDayId,
          ),
      ],
      totalPeriodsThisWeek: totalPeriodsThisWeek,
      completedPeriodsToday: completedPeriodsToday,
      upcomingPeriodsToday: upcomingPeriodsToday,
      unreadNotifications: unreadNotifications,
      scheduleChangeMessage: scheduleChangeMessage,
    );
  }
}
