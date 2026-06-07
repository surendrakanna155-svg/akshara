import 'package:flutter/material.dart';

import '../../../../../features/hostel/hostel_models.dart';

/// Parses Hostel API enum strings and presentation helpers.
abstract final class HostelEnumCodec {
  static HostelRoomStatus parseRoomStatus(String? value) {
    return HostelRoomStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HostelRoomStatus.vacant,
    );
  }

  static String roomStatusToApi(HostelRoomStatus status) => status.name;

  static HostelRoomType parseRoomType(String? value) {
    return HostelRoomType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => HostelRoomType.standard,
    );
  }

  static String roomTypeToApi(HostelRoomType type) => type.name;

  static HostelStudentStatus parseStudentStatus(String? value) {
    return HostelStudentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HostelStudentStatus.resident,
    );
  }

  static String studentStatusToApi(HostelStudentStatus status) => status.name;

  static HostelAttendanceSession parseAttendanceSession(String? value) {
    return HostelAttendanceSession.values.firstWhere(
      (session) => session.name == value,
      orElse: () => HostelAttendanceSession.morning,
    );
  }

  static String attendanceSessionToApi(HostelAttendanceSession session) =>
      session.name;

  static HostelAttendanceStatus parseAttendanceStatus(String? value) {
    return HostelAttendanceStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HostelAttendanceStatus.present,
    );
  }

  static String attendanceStatusToApi(HostelAttendanceStatus status) =>
      status.name;

  static HostelLeaveStatus parseLeaveStatus(String? value) {
    return HostelLeaveStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HostelLeaveStatus.pending,
    );
  }

  static String leaveStatusToApi(HostelLeaveStatus status) => status.name;

  static HostelVisitorStatus parseVisitorStatus(String? value) {
    return HostelVisitorStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HostelVisitorStatus.active,
    );
  }

  static String visitorStatusToApi(HostelVisitorStatus status) => status.name;

  static HostelMealType parseMealType(String? value) {
    return HostelMealType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => HostelMealType.breakfast,
    );
  }

  static String mealTypeToApi(HostelMealType type) => type.name;

  static IconData iconForKpi(String? iconName, String? accentName, String? id) {
    if (iconName != null && iconName.isNotEmpty) {
      return switch (iconName) {
        'bed_outlined' => Icons.bed_outlined,
        'groups_outlined' => Icons.groups_outlined,
        'person_search_outlined' => Icons.person_search_outlined,
        'badge_outlined' => Icons.badge_outlined,
        'restaurant_outlined' => Icons.restaurant_outlined,
        'payments_outlined' => Icons.payments_outlined,
        _ => Icons.insights_outlined,
      };
    }
    return switch (id) {
      'occupancy' => Icons.bed_outlined,
      'present' => Icons.groups_outlined,
      'missing' => Icons.person_search_outlined,
      'visitors' => Icons.badge_outlined,
      'mess_cost' => Icons.restaurant_outlined,
      'fee_pending' => Icons.payments_outlined,
      _ => switch (accentName) {
          'primary' => Icons.bed_outlined,
          'success' => Icons.groups_outlined,
          'warning' => Icons.payments_outlined,
          'error' => Icons.person_search_outlined,
          _ => Icons.insights_outlined,
        },
    };
  }
}
