import 'package:flutter/material.dart';

import '../../../../../features/hr/hr_models.dart';

/// Parses HR API enum strings and presentation helpers.
abstract final class HrEnumCodec {
  static HrEmployeeStatus parseEmployeeStatus(String? value) {
    return HrEmployeeStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HrEmployeeStatus.active,
    );
  }

  static String employeeStatusToApi(HrEmployeeStatus status) => status.name;

  static HrDepartment parseDepartment(String? value) {
    return HrDepartment.values.firstWhere(
      (department) => department.name == value,
      orElse: () => HrDepartment.academics,
    );
  }

  static String departmentToApi(HrDepartment department) => department.name;

  static HrEmployeeRole parseEmployeeRole(String? value) {
    return HrEmployeeRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => HrEmployeeRole.staff,
    );
  }

  static String employeeRoleToApi(HrEmployeeRole role) => role.name;

  static HrAttendanceStatus parseAttendanceStatus(String? value) {
    return HrAttendanceStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HrAttendanceStatus.present,
    );
  }

  static String attendanceStatusToApi(HrAttendanceStatus status) => status.name;

  static HrLeaveStatus parseLeaveStatus(String? value) {
    return HrLeaveStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HrLeaveStatus.pending,
    );
  }

  static String leaveStatusToApi(HrLeaveStatus status) => status.name;

  static HrLeaveType parseLeaveType(String? value) {
    return HrLeaveType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => HrLeaveType.casual,
    );
  }

  static String leaveTypeToApi(HrLeaveType type) => type.name;

  static HrRecruitmentStage parseRecruitmentStage(String? value) {
    return HrRecruitmentStage.values.firstWhere(
      (stage) => stage.name == value,
      orElse: () => HrRecruitmentStage.applied,
    );
  }

  static String recruitmentStageToApi(HrRecruitmentStage stage) => stage.name;

  static HrPayrollStatus parsePayrollStatus(String? value) {
    return HrPayrollStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HrPayrollStatus.draft,
    );
  }

  static String payrollStatusToApi(HrPayrollStatus status) => status.name;

  static HrReviewCycle parseReviewCycle(String? value) {
    return HrReviewCycle.values.firstWhere(
      (cycle) => cycle.name == value,
      orElse: () => HrReviewCycle.q1,
    );
  }

  static String reviewCycleToApi(HrReviewCycle cycle) => cycle.name;

  static HrReviewStatus parseReviewStatus(String? value) {
    return HrReviewStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HrReviewStatus.notStarted,
    );
  }

  static String reviewStatusToApi(HrReviewStatus status) => status.name;

  static IconData iconForKpi(String? iconName, String? accentName) {
    if (iconName != null && iconName.isNotEmpty) {
      return switch (iconName) {
        'groups_outlined' => Icons.groups_outlined,
        'fact_check_outlined' => Icons.fact_check_outlined,
        'event_busy_outlined' => Icons.event_busy_outlined,
        'person_search_outlined' => Icons.person_search_outlined,
        'trending_up_outlined' => Icons.trending_up_outlined,
        'star_outline' => Icons.star_outline,
        _ => Icons.insights_outlined,
      };
    }
    return switch (accentName) {
      'primary' => Icons.groups_outlined,
      'success' => Icons.fact_check_outlined,
      'warning' => Icons.event_busy_outlined,
      _ => Icons.insights_outlined,
    };
  }
}
