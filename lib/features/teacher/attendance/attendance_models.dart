import 'package:flutter/foundation.dart';

/// Student attendance mark for TA-02.
enum StudentAttendanceMark { present, absent, late, unmarked }

extension StudentAttendanceMarkX on StudentAttendanceMark {
  String get label {
    return switch (this) {
      StudentAttendanceMark.present => 'Present',
      StudentAttendanceMark.absent => 'Absent',
      StudentAttendanceMark.late => 'Late',
      StudentAttendanceMark.unmarked => 'Unmarked',
    };
  }
}

/// Teachable class for attendance marking.
@immutable
class TeacherAttendanceClass {
  const TeacherAttendanceClass({
    required this.id,
    required this.label,
    required this.subject,
    required this.periodLabel,
    required this.studentCount,
    required this.isPending,
  });

  final String id;
  final String label;
  final String subject;
  final String periodLabel;
  final int studentCount;
  final bool isPending;
}

/// Student row in attendance list.
@immutable
class TeacherAttendanceStudent {
  const TeacherAttendanceStudent({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.mark,
  });

  final String id;
  final String name;
  final String rollNo;
  final StudentAttendanceMark mark;

  TeacherAttendanceStudent copyWith({StudentAttendanceMark? mark}) {
    return TeacherAttendanceStudent(
      id: id,
      name: name,
      rollNo: rollNo,
      mark: mark ?? this.mark,
    );
  }
}

/// TA-02 screen payload.
@immutable
class TeacherAttendanceData {
  const TeacherAttendanceData({
    required this.classes,
    required this.students,
    required this.selectedClassId,
    required this.unreadNotifications,
    this.draftSavedAt,
    this.isSubmitted = false,
  });

  final List<TeacherAttendanceClass> classes;
  final List<TeacherAttendanceStudent> students;
  final String selectedClassId;
  final int unreadNotifications;
  final String? draftSavedAt;
  final bool isSubmitted;

  int get presentCount =>
      students.where((s) => s.mark == StudentAttendanceMark.present).length;
  int get absentCount =>
      students.where((s) => s.mark == StudentAttendanceMark.absent).length;
  int get lateCount =>
      students.where((s) => s.mark == StudentAttendanceMark.late).length;
  int get unmarkedCount =>
      students.where((s) => s.mark == StudentAttendanceMark.unmarked).length;
}
