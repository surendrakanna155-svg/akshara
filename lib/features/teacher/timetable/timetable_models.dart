import 'package:flutter/foundation.dart';

import '../../../shared/semantic_status.dart';

@immutable
class TeacherTimetablePeriod {
  const TeacherTimetablePeriod({
    required this.id,
    required this.periodLabel,
    required this.timeRange,
    required this.subject,
    required this.classLabel,
    required this.roomLabel,
    required this.status,
  });

  final String id;
  final String periodLabel;
  final String timeRange;
  final String subject;
  final String classLabel;
  final String roomLabel;
  final ClassScheduleStatus status;
}

@immutable
class TeacherTimetableDay {
  const TeacherTimetableDay({
    required this.id,
    required this.shortLabel,
    required this.fullLabel,
    required this.periods,
    this.isSelected = false,
    this.isToday = false,
  });

  final String id;
  final String shortLabel;
  final String fullLabel;
  final List<TeacherTimetablePeriod> periods;
  final bool isSelected;
  final bool isToday;

  TeacherTimetableDay copyWith({bool? isSelected}) {
    return TeacherTimetableDay(
      id: id,
      shortLabel: shortLabel,
      fullLabel: fullLabel,
      periods: periods,
      isSelected: isSelected ?? this.isSelected,
      isToday: isToday,
    );
  }
}

@immutable
class TeacherTimetableData {
  const TeacherTimetableData({
    required this.teacherName,
    required this.weekRangeLabel,
    required this.days,
    required this.unreadNotifications,
  });

  final String teacherName;
  final String weekRangeLabel;
  final List<TeacherTimetableDay> days;
  final int unreadNotifications;

  TeacherTimetableDay? get selectedDay {
    for (final day in days) {
      if (day.isSelected) return day;
    }
    return days.isEmpty ? null : days.first;
  }
}
