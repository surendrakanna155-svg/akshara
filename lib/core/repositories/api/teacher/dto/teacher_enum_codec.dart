import 'package:flutter/material.dart';

import '../../../../../features/teacher/attendance/attendance_models.dart';
import '../../../../../features/teacher/dashboard/teacher_dashboard_provider.dart';
import '../../../../../features/teacher/homework/homework_models.dart';
import '../../../../../features/teacher/leave/leave_models.dart';
import '../../../../../shared/semantic_status.dart';

/// Parses Teacher mobile API enum strings and presentation helpers.
abstract final class TeacherEnumCodec {
  /// Parse the wire mark string. The backend persists/returns snake_case marks
  /// (present/absent/late/excused/half_day, matching the attendance_records
  /// CHECK), so `half_day` is decoded explicitly; the rest match enum `.name`.
  static StudentAttendanceMark parseStudentAttendanceMark(String? value) {
    if (value == 'half_day') return StudentAttendanceMark.halfDay;
    return StudentAttendanceMark.values.firstWhere(
      (mark) => mark.name == value,
      orElse: () => StudentAttendanceMark.unmarked,
    );
  }

  /// Serialize to the wire mark string. `half_day` is emitted in snake_case so
  /// the value satisfies the attendance_records CHECK constraint; the rest use
  /// enum `.name`.
  static String studentAttendanceMarkToApi(StudentAttendanceMark mark) =>
      mark == StudentAttendanceMark.halfDay ? 'half_day' : mark.name;

  static HomeworkReviewStatus parseHomeworkReviewStatus(String? value) {
    return HomeworkReviewStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HomeworkReviewStatus.pending,
    );
  }

  static String homeworkReviewStatusToApi(HomeworkReviewStatus status) =>
      status.name;

  static TeacherLeaveStatus parseTeacherLeaveStatus(String? value) {
    return TeacherLeaveStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TeacherLeaveStatus.pending,
    );
  }

  static String teacherLeaveStatusToApi(TeacherLeaveStatus status) =>
      status.name;

  static ClassScheduleStatus parseClassScheduleStatus(String? value) {
    return ClassScheduleStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ClassScheduleStatus.upcoming,
    );
  }

  static String classScheduleStatusToApi(ClassScheduleStatus status) =>
      status.name;

  static StaffCheckInStatus parseStaffCheckInStatus(String? value) {
    return StaffCheckInStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => StaffCheckInStatus.notCheckedIn,
    );
  }

  static String staffCheckInStatusToApi(StaffCheckInStatus status) =>
      status.name;

  static IconData iconForQuickAction(String? iconName, String? id) {
    if (iconName != null && iconName.isNotEmpty) {
      return _iconFromName(iconName);
    }
    return switch (id) {
      'mark_attendance' => Icons.fact_check_outlined,
      'homework' => Icons.assignment_outlined,
      'timetable' => Icons.calendar_view_week_outlined,
      'exams' => Icons.grading_outlined,
      'messages' => Icons.forum_outlined,
      _ => Icons.touch_app_outlined,
    };
  }

  static IconData iconForPendingTask(String? iconName, String? id) {
    if (iconName != null && iconName.isNotEmpty) {
      return _iconFromName(iconName);
    }
    return switch (id) {
      'hw_review' => Icons.assignment_outlined,
      'unread_messages' => Icons.chat_bubble_outline,
      'leave' => Icons.event_busy_outlined,
      _ => Icons.task_outlined,
    };
  }

  static IconData _iconFromName(String iconName) {
    return switch (iconName) {
      'fact_check_outlined' => Icons.fact_check_outlined,
      'assignment_outlined' => Icons.assignment_outlined,
      'calendar_view_week_outlined' => Icons.calendar_view_week_outlined,
      'grading_outlined' => Icons.grading_outlined,
      'forum_outlined' => Icons.forum_outlined,
      'chat_bubble_outline' => Icons.chat_bubble_outline,
      'event_busy_outlined' => Icons.event_busy_outlined,
      _ => Icons.insights_outlined,
    };
  }
}
