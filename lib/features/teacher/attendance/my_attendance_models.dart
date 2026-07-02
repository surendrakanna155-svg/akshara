import 'package:flutter/foundation.dart';

/// TCH-9 — a staff member's OWN attendance day, derived by the backend from the
/// append-only check-in ledger (`GET /staff-attendance/my-history`). READ-ONLY:
/// the teacher never mutates their own attendance from here.
enum MyAttendanceStatus { present, late, absent, holiday }

extension MyAttendanceStatusX on MyAttendanceStatus {
  String get label {
    return switch (this) {
      MyAttendanceStatus.present => 'Present',
      MyAttendanceStatus.late => 'Late',
      MyAttendanceStatus.absent => 'Absent',
      MyAttendanceStatus.holiday => 'Holiday',
    };
  }

  static MyAttendanceStatus fromCode(String? code) {
    return switch (code) {
      'present' => MyAttendanceStatus.present,
      'late' => MyAttendanceStatus.late,
      'absent' => MyAttendanceStatus.absent,
      'holiday' => MyAttendanceStatus.holiday,
      _ => MyAttendanceStatus.absent,
    };
  }
}

/// One day of the caller's own attendance history.
@immutable
class MyAttendanceDay {
  const MyAttendanceDay({
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.workingMinutes,
    this.manualOverride = false,
  });

  /// yyyy-mm-dd.
  final String date;

  /// Earliest check-in of the day (ISO), null when absent/holiday.
  final String? checkIn;

  /// Latest check-out of the day (ISO), null when there is no completed pair.
  final String? checkOut;

  /// checkOut - checkIn in whole minutes; null without a completed pair.
  final int? workingMinutes;

  final MyAttendanceStatus status;

  /// True when an approved manual attendance request covers this day.
  final bool manualOverride;

  bool get isLate => status == MyAttendanceStatus.late;

  /// "h:mm" working-hours label, or null without a completed pair.
  String? get workingHoursLabel {
    final minutes = workingMinutes;
    if (minutes == null) return null;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

/// Month-level roll-up of the caller's attendance.
@immutable
class MyAttendanceSummary {
  const MyAttendanceSummary({
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.workingDaysInMonth,
    this.avgWorkingMinutes,
  });

  /// On-time attended days (disjoint from [lateDays]).
  final int presentDays;
  final int lateDays;
  final int absentDays;

  /// Working days in the full month (calendar days minus holidays).
  final int workingDaysInMonth;

  /// Mean of completed-pair working minutes; null with no pairs.
  final int? avgWorkingMinutes;

  /// "h:mm" average working-hours label, or "—" when there are no pairs.
  String get avgWorkingHoursLabel {
    final minutes = avgWorkingMinutes;
    if (minutes == null) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

/// The full TCH-9 self-history for one YYYY-MM window.
@immutable
class MyAttendanceHistory {
  const MyAttendanceHistory({
    required this.month,
    required this.days,
    required this.summary,
    this.today,
    this.yesterday,
  });

  /// YYYY-MM.
  final String month;
  final List<MyAttendanceDay> days;
  final MyAttendanceSummary summary;
  final MyAttendanceDay? today;
  final MyAttendanceDay? yesterday;

  static const empty = MyAttendanceHistory(
    month: '',
    days: [],
    summary: MyAttendanceSummary(
      presentDays: 0,
      lateDays: 0,
      absentDays: 0,
      workingDaysInMonth: 0,
    ),
  );
}
