import 'package:flutter/material.dart';

import '../../../../../features/parent/attendance/attendance_models.dart';
import '../../../../../features/parent/dashboard/parent_dashboard_provider.dart';
import '../../../../../features/parent/fees/fees_provider.dart';
import '../../../../../features/parent/homework/homework_models.dart';
import '../../../../../features/parent/leave/leave_models.dart';
import '../../../../../features/parent/notices/notices_models.dart';
import '../../../../../features/parent/timetable/timetable_models.dart';

/// Parses Parent mobile API enum strings and presentation helpers.
abstract final class ParentEnumCodec {
  static AttendanceDayStatus parseAttendanceDayStatus(String? value) {
    return AttendanceDayStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AttendanceDayStatus.empty,
    );
  }

  static String attendanceDayStatusToApi(AttendanceDayStatus status) =>
      status.name;

  static ParentHomeworkStatus parseHomeworkStatus(String? value) {
    return ParentHomeworkStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ParentHomeworkStatus.pending,
    );
  }

  static String homeworkStatusToApi(ParentHomeworkStatus status) => status.name;

  static TimetablePeriodStatus parseTimetablePeriodStatus(String? value) {
    return TimetablePeriodStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TimetablePeriodStatus.upcoming,
    );
  }

  static String timetablePeriodStatusToApi(TimetablePeriodStatus status) =>
      status.name;

  static NoticeCategory parseNoticeCategory(String? value) {
    return NoticeCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => NoticeCategory.general,
    );
  }

  static String noticeCategoryToApi(NoticeCategory category) => category.name;

  static LeaveType parseLeaveType(String? value) {
    return LeaveType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => LeaveType.other,
    );
  }

  static String leaveTypeToApi(LeaveType type) => type.name;

  static LeaveStatus parseLeaveStatus(String? value) {
    return LeaveStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => LeaveStatus.pending,
    );
  }

  static String leaveStatusToApi(LeaveStatus status) => status.name;

  static FeeInstallmentStatus parseFeeInstallmentStatus(String? value) {
    return FeeInstallmentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => FeeInstallmentStatus.upcoming,
    );
  }

  static String feeInstallmentStatusToApi(FeeInstallmentStatus status) =>
      status.name;

  static DashboardChipTone parseDashboardChipTone(String? value) {
    return DashboardChipTone.values.firstWhere(
      (tone) => tone.name == value,
      orElse: () => DashboardChipTone.primary,
    );
  }

  static String dashboardChipToneToApi(DashboardChipTone tone) => tone.name;

  static IconData iconForQuickAction(String? iconName, String? id) {
    if (iconName != null && iconName.isNotEmpty) {
      return _iconFromName(iconName);
    }
    return switch (id) {
      'pay_fee' => Icons.payments_outlined,
      'homework' => Icons.assignment_outlined,
      'timetable' => Icons.calendar_view_week_outlined,
      'exams' => Icons.grading_outlined,
      _ => Icons.touch_app_outlined,
    };
  }

  static IconData iconForSummary(String? iconName, String? id) {
    if (iconName != null && iconName.isNotEmpty) {
      return _iconFromName(iconName);
    }
    return switch (id) {
      'attendance' => Icons.fact_check_outlined,
      'homework' => Icons.assignment_outlined,
      'timetable' => Icons.calendar_view_week_outlined,
      'fees' => Icons.account_balance_wallet_outlined,
      _ => Icons.info_outline,
    };
  }

  static IconData _iconFromName(String iconName) {
    return switch (iconName) {
      'payments_outlined' => Icons.payments_outlined,
      'assignment_outlined' => Icons.assignment_outlined,
      'calendar_view_week_outlined' => Icons.calendar_view_week_outlined,
      'grading_outlined' => Icons.grading_outlined,
      'fact_check_outlined' => Icons.fact_check_outlined,
      'account_balance_wallet_outlined' => Icons.account_balance_wallet_outlined,
      _ => Icons.insights_outlined,
    };
  }
}
