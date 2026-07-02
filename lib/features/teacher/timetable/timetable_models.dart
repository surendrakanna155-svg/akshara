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
    this.substituteTeacherUserId,
    this.substituteTeacherName,
    this.coveringForTeacherName,
  });

  final String id;
  final String periodLabel;
  final String timeRange;
  final String subject;
  final String classLabel;
  final String roomLabel;
  final ClassScheduleStatus status;

  /// TCH-4 — when this period is covered by a substitute, the substitute's user
  /// id / display name (from the daily-substitution overlay). Null when the
  /// regularly-assigned teacher takes the class.
  final String? substituteTeacherUserId;
  final String? substituteTeacherName;

  /// TCH-4 — set on the covering teacher's own view: whose class they are
  /// covering (the original teacher's name).
  final String? coveringForTeacherName;

  /// True when this period is a substitution (has a substitute assigned).
  bool get isCovered =>
      (substituteTeacherUserId != null &&
          substituteTeacherUserId!.isNotEmpty) ||
      (substituteTeacherName != null && substituteTeacherName!.isNotEmpty);

  /// True on the covering teacher's own view — they are picking up this class.
  bool get isCoveringForSomeone =>
      coveringForTeacherName != null && coveringForTeacherName!.isNotEmpty;
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
