import 'package:flutter/material.dart';

import '../../../../../features/admissions/admissions_models.dart';
import '../../../../../features/sis/sis_models.dart';

/// Parses SIS API enum strings and presentation helpers.
abstract final class SisEnumCodec {
  static SisStudentStatus parseStudentStatus(String? value) {
    return SisStudentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SisStudentStatus.active,
    );
  }

  static String studentStatusToApi(SisStudentStatus status) => status.name;

  static EnrollmentConversionStatus parseConversionStatus(String? value) {
    return EnrollmentConversionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => EnrollmentConversionStatus.pending,
    );
  }

  static String conversionStatusToApi(EnrollmentConversionStatus status) =>
      status.name;

  static IconData iconForKpi(String? iconName, String? accentName) {
    if (iconName != null && iconName.isNotEmpty) {
      return switch (iconName) {
        'groups_outlined' => Icons.groups_outlined,
        'person_add_outlined' => Icons.person_add_outlined,
        'verified_outlined' => Icons.verified_outlined,
        'swap_horiz_outlined' => Icons.swap_horiz_outlined,
        'class_outlined' => Icons.class_outlined,
        'grid_view_outlined' => Icons.grid_view_outlined,
        _ => Icons.insights_outlined,
      };
    }
    return switch (accentName) {
      'primary' => Icons.groups_outlined,
      'success' => Icons.verified_outlined,
      'warning' => Icons.swap_horiz_outlined,
      _ => Icons.insights_outlined,
    };
  }
}
