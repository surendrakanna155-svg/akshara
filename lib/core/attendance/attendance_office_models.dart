// OFFICE / ADMIN student-attendance read models (ATT-1, ATT-2, ATT-4, ATT-D1,
// ATT-D2). All read-only; there is no write model here.

/// ATT-1 — a single student's mark in the register for a class + date.
class AttendanceRegisterEntry {
  const AttendanceRegisterEntry({
    required this.studentId,
    required this.name,
    required this.classLabel,
    required this.mark,
    this.roll,
  });

  final String studentId;
  final String name;
  final String classLabel;
  final String mark;
  final String? roll;
}

/// ATT-2 — one student's row in the monthly matrix.
class MonthlyRegisterStudent {
  const MonthlyRegisterStudent({
    required this.studentId,
    required this.name,
    required this.classLabel,
    required this.marks,
    required this.presentDays,
    required this.markedDays,
    required this.percentPresent,
    this.roll,
  });

  final String studentId;
  final String name;
  final String classLabel;

  /// dayOfMonth (1..31) -> single-letter mark code P/A/L/E ('-' if unknown).
  final Map<int, String> marks;
  final int presentDays;
  final int markedDays;
  final int percentPresent;
  final String? roll;

  /// The mark code for [day] (1-based), or '–' when not marked.
  String codeForDay(int day) => marks[day] ?? '–';
}

/// ATT-2 — full monthly register for a class.
class MonthlyRegister {
  const MonthlyRegister({
    required this.classLabel,
    required this.month,
    required this.dayCount,
    required this.students,
  });

  final String classLabel;
  final String month; // YYYY-MM
  final int dayCount; // number of days in the month
  final List<MonthlyRegisterStudent> students;
}

/// ATT-4 — a class with no submitted session for the target date.
class PendingAttendanceClass {
  const PendingAttendanceClass({
    required this.classLabel,
    required this.status,
    this.takenBy,
    this.teacherName,
    this.lastSavedAt,
  });

  final String classLabel;

  /// 'draft' when a draft session exists, 'missing' when no session at all.
  final String status;
  final String? takenBy;
  final String? teacherName;
  final DateTime? lastSavedAt;

  bool get isDraft => status == 'draft';
}

/// ATT-D1 — a student flagged for N consecutive absences.
class ConsecutiveAbsenceStudent {
  const ConsecutiveAbsenceStudent({
    required this.studentId,
    required this.name,
    required this.classLabel,
    required this.consecutiveDays,
    this.roll,
    this.lastAbsentDate,
  });

  final String studentId;
  final String name;
  final String classLabel;
  final int consecutiveDays;
  final String? roll;
  final DateTime? lastAbsentDate;
}

/// ATT-D2 — a student whose attendance % is below the threshold.
class ShortAttendanceStudent {
  const ShortAttendanceStudent({
    required this.studentId,
    required this.name,
    required this.classLabel,
    required this.presentDays,
    required this.markedDays,
    required this.percentPresent,
    this.roll,
  });

  final String studentId;
  final String name;
  final String classLabel;
  final int presentDays;
  final int markedDays;
  final int percentPresent;
  final String? roll;
}
