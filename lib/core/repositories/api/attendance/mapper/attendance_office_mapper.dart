import '../../../../attendance/attendance_office_models.dart';

/// Maps OFFICE / ADMIN attendance API payloads to domain models.
class AttendanceOfficeMapper {
  const AttendanceOfficeMapper();

  AttendanceRegisterEntry registerEntry(Map<String, dynamic> json) {
    return AttendanceRegisterEntry(
      studentId: json['studentId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      classLabel: json['classLabel'] as String? ?? '',
      mark: json['mark'] as String? ?? '',
      roll: json['roll'] as String?,
    );
  }

  List<AttendanceRegisterEntry> registerList(List<dynamic> items) => items
      .map((e) => registerEntry(e as Map<String, dynamic>))
      .toList(growable: false);

  MonthlyRegister monthlyRegister(Map<String, dynamic> json) {
    final studentsRaw = (json['students'] as List<dynamic>? ?? const []);
    return MonthlyRegister(
      classLabel: json['classLabel'] as String? ?? '',
      month: json['month'] as String? ?? '',
      dayCount: (json['dayCount'] as num?)?.toInt() ?? 31,
      students: studentsRaw
          .map((e) => _monthlyStudent(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  MonthlyRegisterStudent _monthlyStudent(Map<String, dynamic> json) {
    final marksRaw = (json['marks'] as Map<String, dynamic>? ?? const {});
    final marks = <int, String>{};
    marksRaw.forEach((key, value) {
      final day = int.tryParse(key);
      if (day != null) marks[day] = value as String? ?? '-';
    });
    return MonthlyRegisterStudent(
      studentId: json['studentId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      classLabel: json['classLabel'] as String? ?? '',
      marks: marks,
      presentDays: (json['presentDays'] as num?)?.toInt() ?? 0,
      markedDays: (json['markedDays'] as num?)?.toInt() ?? 0,
      percentPresent: (json['percentPresent'] as num?)?.toInt() ?? 0,
      roll: json['roll'] as String?,
    );
  }

  PendingAttendanceClass pendingClass(Map<String, dynamic> json) {
    return PendingAttendanceClass(
      classLabel: json['classLabel'] as String? ?? '',
      status: json['status'] as String? ?? 'missing',
      takenBy: json['takenBy'] as String?,
      teacherName: json['teacherName'] as String?,
      lastSavedAt: _parseDate(json['lastSavedAt']),
    );
  }

  List<PendingAttendanceClass> pendingList(List<dynamic> items) => items
      .map((e) => pendingClass(e as Map<String, dynamic>))
      .toList(growable: false);

  ConsecutiveAbsenceStudent consecutiveAbsence(Map<String, dynamic> json) {
    return ConsecutiveAbsenceStudent(
      studentId: json['studentId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      classLabel: json['classLabel'] as String? ?? '',
      consecutiveDays: (json['consecutiveDays'] as num?)?.toInt() ?? 0,
      roll: json['roll'] as String?,
      lastAbsentDate: _parseDate(json['lastAbsentDate']),
    );
  }

  List<ConsecutiveAbsenceStudent> consecutiveAbsenceList(List<dynamic> items) =>
      items
          .map((e) => consecutiveAbsence(e as Map<String, dynamic>))
          .toList(growable: false);

  ShortAttendanceStudent shortAttendance(Map<String, dynamic> json) {
    return ShortAttendanceStudent(
      studentId: json['studentId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      classLabel: json['classLabel'] as String? ?? '',
      presentDays: (json['presentDays'] as num?)?.toInt() ?? 0,
      markedDays: (json['markedDays'] as num?)?.toInt() ?? 0,
      percentPresent: (json['percentPresent'] as num?)?.toInt() ?? 0,
      roll: json['roll'] as String?,
    );
  }

  List<ShortAttendanceStudent> shortAttendanceList(List<dynamic> items) => items
      .map((e) => shortAttendance(e as Map<String, dynamic>))
      .toList(growable: false);

  DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
