import 'package:flutter/material.dart';

import '../../../../../features/parent/attendance/attendance_models.dart';
import '../../../../../features/parent/timetable/timetable_models.dart';
import '../../../../../features/student/dashboard/student_dashboard_provider.dart';
import '../../../../../features/student/homework/homework_models.dart';
import '../../../../../features/student/notices/notices_models.dart';
import '../../../../../shared/semantic_status.dart';

/// Parses Student mobile API enum strings and presentation helpers.
abstract final class StudentEnumCodec {
  static AttendanceDayStatus parseAttendanceDayStatus(String? value) {
    return AttendanceDayStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AttendanceDayStatus.empty,
    );
  }

  static String attendanceDayStatusToApi(AttendanceDayStatus status) =>
      status.name;

  static StudentHomeworkStatus parseHomeworkStatus(String? value) {
    return StudentHomeworkStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => StudentHomeworkStatus.pending,
    );
  }

  static String homeworkStatusToApi(StudentHomeworkStatus status) => status.name;

  static TimetablePeriodStatus parseTimetablePeriodStatus(String? value) {
    return TimetablePeriodStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TimetablePeriodStatus.upcoming,
    );
  }

  static String timetablePeriodStatusToApi(TimetablePeriodStatus status) =>
      status.name;

  static StudentNoticeScope parseNoticeScope(String? value) {
    return StudentNoticeScope.values.firstWhere(
      (scope) => scope.name == value,
      orElse: () => StudentNoticeScope.school,
    );
  }

  static String noticeScopeToApi(StudentNoticeScope scope) => scope.name;

  static StudentNoticePriority parseNoticePriority(String? value) {
    return StudentNoticePriority.values.firstWhere(
      (priority) => priority.name == value,
      orElse: () => StudentNoticePriority.normal,
    );
  }

  static String noticePriorityToApi(StudentNoticePriority priority) =>
      priority.name;

  static PeriodState parsePeriodState(String? value) {
    return PeriodState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => PeriodState.later,
    );
  }

  static String periodStateToApi(PeriodState state) => state.name;

  static StudentKpiTone parseStudentKpiTone(String? value) {
    return StudentKpiTone.values.firstWhere(
      (tone) => tone.name == value,
      orElse: () => StudentKpiTone.primary,
    );
  }

  static String studentKpiToneToApi(StudentKpiTone tone) => tone.name;

  static HomeworkStatus parseHomeworkDueStatus(String? value) {
    return HomeworkStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HomeworkStatus.pending,
    );
  }

  static String homeworkDueStatusToApi(HomeworkStatus status) => status.name;

  static IconData iconForQuickAction(String? iconName, String? id) {
    if (iconName != null && iconName.isNotEmpty) {
      return _iconFromName(iconName);
    }
    return switch (id) {
      'homework' => Icons.assignment_outlined,
      'exams' => Icons.grading_outlined,
      'timetable' => Icons.calendar_view_week_outlined,
      'notices' => Icons.campaign_outlined,
      _ => Icons.touch_app_outlined,
    };
  }

  static IconData iconForHomeworkDue(String? iconName, String? subject) {
    if (iconName != null && iconName.isNotEmpty) {
      return _iconFromName(iconName);
    }
    return switch (subject?.toLowerCase()) {
      'mathematics' || 'math' => Icons.calculate_outlined,
      'science' => Icons.science_outlined,
      'english' => Icons.menu_book_outlined,
      _ => Icons.assignment_outlined,
    };
  }

  static IconData _iconFromName(String iconName) {
    return switch (iconName) {
      'assignment_outlined' => Icons.assignment_outlined,
      'grading_outlined' => Icons.grading_outlined,
      'calendar_view_week_outlined' => Icons.calendar_view_week_outlined,
      'campaign_outlined' => Icons.campaign_outlined,
      'calculate_outlined' => Icons.calculate_outlined,
      'science_outlined' => Icons.science_outlined,
      'menu_book_outlined' => Icons.menu_book_outlined,
      _ => Icons.insights_outlined,
    };
  }
}
