import 'package:flutter/material.dart';

import '../../../theme/theme_extensions.dart';

/// Attendance status for a calendar day or log row (PA-02 §3).
enum AttendanceDayStatus {
  present,
  absent,
  late,
  halfDay,
  excused,
  holiday,
  empty,
  future,
}

/// Shared chip colors for [AttendanceDayStatus] across PA-02 widgets.
extension AttendanceDayStatusStyle on AttendanceDayStatus {
  ({String label, Color background, Color foreground}) resolve(
    BuildContext context,
  ) {
    final colors = context.colors;
    final ext = context.akshara;

    return switch (this) {
      AttendanceDayStatus.present => (
          label: 'Present',
          background: ext.successContainer,
          foreground: ext.success,
        ),
      AttendanceDayStatus.absent => (
          label: 'Absent',
          background: colors.errorContainer,
          foreground: colors.error,
        ),
      AttendanceDayStatus.late => (
          label: 'Late',
          background: ext.warningContainer,
          foreground: ext.warning,
        ),
      AttendanceDayStatus.halfDay => (
          label: 'Half-day',
          background: ext.indigoContainer,
          foreground: ext.indigo,
        ),
      AttendanceDayStatus.excused => (
          label: 'Excused',
          background: ext.tertiaryContainer,
          foreground: ext.tertiary,
        ),
      AttendanceDayStatus.holiday => (
          label: 'Holiday',
          background: ext.surfaceContainerHighest,
          foreground: colors.onSurfaceVariant,
        ),
      AttendanceDayStatus.empty ||
      AttendanceDayStatus.future =>
        (
          label: '—',
          background: colors.surfaceContainerLow,
          foreground: colors.onSurfaceVariant,
        ),
    };
  }
}

/// Single calendar cell in the month grid.
@immutable
class AttendanceCalendarDay {
  const AttendanceCalendarDay({
    required this.date,
    required this.status,
    this.dayNumber,
    this.isSelected = false,
    this.markedAt,
    this.detailTitle,
    this.detailBody,
    this.detailNote,
  });

  /// `null` [dayNumber] denotes a leading/trailing padding cell.
  final DateTime? date;
  final AttendanceDayStatus status;
  final int? dayNumber;
  final bool isSelected;
  final String? markedAt;
  final String? detailTitle;
  final String? detailBody;
  final String? detailNote;

  bool get isPadding => dayNumber == null;
  bool get isTappable =>
      !isPadding &&
      status != AttendanceDayStatus.empty &&
      status != AttendanceDayStatus.future;

  AttendanceCalendarDay copyWith({
    DateTime? date,
    AttendanceDayStatus? status,
    int? dayNumber,
    bool? isSelected,
    String? markedAt,
    String? detailTitle,
    String? detailBody,
    String? detailNote,
  }) {
    return AttendanceCalendarDay(
      date: date ?? this.date,
      status: status ?? this.status,
      dayNumber: dayNumber ?? this.dayNumber,
      isSelected: isSelected ?? this.isSelected,
      markedAt: markedAt ?? this.markedAt,
      detailTitle: detailTitle ?? this.detailTitle,
      detailBody: detailBody ?? this.detailBody,
      detailNote: detailNote ?? this.detailNote,
    );
  }
}

/// Compact KPI metrics strip (PA-02 §3 Row/KPISummary).
@immutable
class AttendanceKpiMetrics {
  const AttendanceKpiMetrics({
    required this.attendancePercent,
    required this.absentDays,
    required this.lateDays,
  });

  final int attendancePercent;
  final int absentDays;
  final int lateDays;
}

/// Recent attendance log row (PA-02 Parent/AttendanceDayRow).
@immutable
class AttendanceDayLog {
  const AttendanceDayLog({
    required this.date,
    required this.status,
    required this.detail,
    required this.detailTitle,
    required this.detailBody,
    this.detailNote,
  });

  final DateTime date;
  final AttendanceDayStatus status;
  final String detail;
  final String detailTitle;
  final String detailBody;
  final String? detailNote;
}

/// Full month payload for [ParentAttendanceScreen].
@immutable
class AttendanceMonthData {
  const AttendanceMonthData({
    required this.month,
    required this.childName,
    required this.childClass,
    required this.kpi,
    required this.calendarDays,
    required this.recentLogs,
    this.warningBannerMessage,
    this.unreadNotifications = 0,
    this.classTeacherPhone,
  });

  final DateTime month;
  final String childName;
  final String childClass;
  final AttendanceKpiMetrics kpi;
  final List<AttendanceCalendarDay> calendarDays;
  final List<AttendanceDayLog> recentLogs;
  final String? warningBannerMessage;
  final int unreadNotifications;
  final String? classTeacherPhone;

  String get monthLabel {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month.month - 1]} ${month.year}';
  }

  /// Neutral-empty placeholder used as the production fallback before the
  /// FutureProvider resolves (no fabricated identity or attendance data).
  static AttendanceMonthData empty({DateTime? month}) {
    final target = DateTime(month?.year ?? 2026, month?.month ?? 6, 1);
    return AttendanceMonthData(
      month: target,
      childName: '',
      childClass: '',
      kpi: const AttendanceKpiMetrics(
        attendancePercent: 0,
        absentDays: 0,
        lateDays: 0,
      ),
      calendarDays: const [],
      recentLogs: const [],
      unreadNotifications: 0,
    );
  }

  static AttendanceMonthData mock({DateTime? month}) {
    final target = DateTime(month?.year ?? 2026, month?.month ?? 6, 1);
    if (target.year == 2026 && target.month == 6) {
      return _june2026();
    }
    return _genericMonth(target);
  }

  static AttendanceMonthData _june2026() {
    const childName = 'Ravi Kumar';
    const childClass = '8-A';

    final dayStatuses = <int, AttendanceDayStatus>{
      1: AttendanceDayStatus.holiday,
      2: AttendanceDayStatus.holiday,
      3: AttendanceDayStatus.holiday,
      4: AttendanceDayStatus.present,
      5: AttendanceDayStatus.absent,
      6: AttendanceDayStatus.present,
      7: AttendanceDayStatus.present,
      8: AttendanceDayStatus.late,
      9: AttendanceDayStatus.present,
      10: AttendanceDayStatus.present,
      11: AttendanceDayStatus.holiday,
      12: AttendanceDayStatus.present,
      13: AttendanceDayStatus.present,
      14: AttendanceDayStatus.absent,
      15: AttendanceDayStatus.present,
      16: AttendanceDayStatus.present,
      17: AttendanceDayStatus.present,
      18: AttendanceDayStatus.late,
      19: AttendanceDayStatus.present,
      20: AttendanceDayStatus.present,
    };

    final markedAt = <int, String>{
      4: '9:12 AM',
      5: '',
      6: '9:08 AM',
      7: '9:05 AM',
      8: '9:22 AM',
      14: '',
      18: '9:18 AM',
    };

    final calendarDays = _buildCalendarGrid(
      year: 2026,
      month: 6,
      dayStatuses: dayStatuses,
      markedAt: markedAt,
      today: DateTime(2026, 6, 5),
    );

    final recentLogs = <AttendanceDayLog>[
      AttendanceDayLog(
        date: DateTime(2026, 6, 4),
        status: AttendanceDayStatus.present,
        detail: 'Marked 9:12 AM',
        detailTitle: 'Wednesday, 4 June 2026',
        detailBody: 'Present — marked on time',
        detailNote: 'Contact class teacher if incorrect',
      ),
      AttendanceDayLog(
        date: DateTime(2026, 6, 5),
        status: AttendanceDayStatus.absent,
        detail: 'No mark by 10:00 AM',
        detailTitle: 'Thursday, 5 June 2026',
        detailBody: 'Absent — no mark recorded by 10:00 AM',
        detailNote: 'Contact class teacher if incorrect',
      ),
      AttendanceDayLog(
        date: DateTime(2026, 6, 6),
        status: AttendanceDayStatus.present,
        detail: 'Marked 9:08 AM',
        detailTitle: 'Friday, 6 June 2026',
        detailBody: 'Present — marked on time',
      ),
      AttendanceDayLog(
        date: DateTime(2026, 6, 7),
        status: AttendanceDayStatus.present,
        detail: 'Marked 9:05 AM',
        detailTitle: 'Saturday, 7 June 2026',
        detailBody: 'Present — marked on time',
      ),
      AttendanceDayLog(
        date: DateTime(2026, 6, 8),
        status: AttendanceDayStatus.late,
        detail: 'Marked 9:22 AM',
        detailTitle: 'Sunday, 8 June 2026',
        detailBody: 'Late — marked after school start time',
        detailNote: 'Contact class teacher if incorrect',
      ),
    ];

    return AttendanceMonthData(
      month: DateTime(2026, 6, 1),
      childName: childName,
      childClass: childClass,
      kpi: const AttendanceKpiMetrics(
        attendancePercent: 94,
        absentDays: 2,
        lateDays: 1,
      ),
      calendarDays: calendarDays,
      recentLogs: recentLogs,
      warningBannerMessage:
          'Ravi was absent 2 days this month — above class average',
      unreadNotifications: 2,
    );
  }

  static AttendanceMonthData _genericMonth(DateTime month) {
    final now = DateTime.now();
    final isCurrentMonth =
        month.year == now.year && month.month == now.month;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    final dayStatuses = <int, AttendanceDayStatus>{};
    final markedAt = <int, String>{};
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      if (date.weekday == DateTime.sunday) {
        dayStatuses[d] = AttendanceDayStatus.holiday;
      } else if (isCurrentMonth && date.isAfter(now)) {
        dayStatuses[d] = AttendanceDayStatus.future;
      } else {
        dayStatuses[d] = AttendanceDayStatus.present;
        markedAt[d] = '9:10 AM';
      }
    }

    return AttendanceMonthData(
      month: DateTime(month.year, month.month, 1),
      childName: 'Ravi Kumar',
      childClass: '8-A',
      kpi: const AttendanceKpiMetrics(
        attendancePercent: 100,
        absentDays: 0,
        lateDays: 0,
      ),
      calendarDays: _buildCalendarGrid(
        year: month.year,
        month: month.month,
        dayStatuses: dayStatuses,
        markedAt: markedAt,
        today: isCurrentMonth ? now : DateTime(month.year, month.month, 15),
      ),
      recentLogs: const [],
    );
  }

  static List<AttendanceCalendarDay> _buildCalendarGrid({
    required int year,
    required int month,
    required Map<int, AttendanceDayStatus> dayStatuses,
    required Map<int, String> markedAt,
    required DateTime today,
    DateTime? selectedDate,
  }) {
    final firstOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final leadingEmpty = firstOfMonth.weekday % 7;
    final cells = <AttendanceCalendarDay>[];

    for (var i = 0; i < leadingEmpty; i++) {
      cells.add(
        const AttendanceCalendarDay(
          date: null,
          status: AttendanceDayStatus.empty,
          dayNumber: null,
        ),
      );
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      var status = dayStatuses[day] ?? AttendanceDayStatus.empty;
      if (status == AttendanceDayStatus.empty && date.isAfter(today)) {
        status = AttendanceDayStatus.future;
      }

      final mark = markedAt[day];
      cells.add(
        AttendanceCalendarDay(
          date: date,
          status: status,
          dayNumber: day,
          isSelected: selectedDate != null &&
              DateUtils.isSameDay(date, selectedDate),
          markedAt: mark,
          detailTitle: _formatDetailTitle(date),
          detailBody: _detailBody(status, mark),
          detailNote: status == AttendanceDayStatus.absent ||
                  status == AttendanceDayStatus.late
              ? 'Contact class teacher if incorrect'
              : null,
        ),
      );
    }

    while (cells.length % 7 != 0) {
      cells.add(
        const AttendanceCalendarDay(
          date: null,
          status: AttendanceDayStatus.empty,
          dayNumber: null,
        ),
      );
    }

    return cells;
  }

  static String _formatDetailTitle(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _detailBody(AttendanceDayStatus status, String? markedAt) {
    return switch (status) {
      AttendanceDayStatus.present => markedAt != null && markedAt.isNotEmpty
          ? 'Present — marked at $markedAt'
          : 'Present — marked on time',
      AttendanceDayStatus.absent =>
        'Absent — no mark recorded by 10:00 AM',
      AttendanceDayStatus.late => markedAt != null && markedAt.isNotEmpty
          ? 'Late — marked at $markedAt'
          : 'Late — marked after school start time',
      AttendanceDayStatus.halfDay => 'Half-day — attended part of the day',
      AttendanceDayStatus.excused => 'Excused — approved leave on record',
      AttendanceDayStatus.holiday => 'Holiday — no attendance required',
      AttendanceDayStatus.future => 'Future date — attendance not yet recorded',
      AttendanceDayStatus.empty => 'No attendance data',
    };
  }

  AttendanceMonthData withSelectedDay(DateTime? selected) {
    return AttendanceMonthData(
      month: month,
      childName: childName,
      childClass: childClass,
      kpi: kpi,
      calendarDays: [
        for (final cell in calendarDays)
          cell.copyWith(
            isSelected: cell.date != null &&
                selected != null &&
                DateUtils.isSameDay(cell.date!, selected),
          ),
      ],
      recentLogs: recentLogs,
      warningBannerMessage: warningBannerMessage,
      unreadNotifications: unreadNotifications,
    );
  }
}
