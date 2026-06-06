import 'package:flutter_riverpod/flutter_riverpod.dart';

final sisAdmissionsConversionLoadingProvider = StateProvider<bool>(
  (ref) => false,
);
final sisAdmissionsConversionErrorProvider = StateProvider<bool>(
  (ref) => false,
);
final sisSelectedEnrollmentIdProvider = StateProvider<String?>((ref) => null);

/// Generates admission number for a pending enrollment conversion.
String generateAdmissionNumber(String enrollmentId) {
  final suffix = enrollmentId.replaceAll('enr_', '').padLeft(4, '0');
  return 'ADM-2026-$suffix';
}

/// Builds SIS student id from enrollment.
String generateSisStudentId(String enrollmentId) {
  final suffix = enrollmentId.replaceAll('enr_', '');
  return 'SIS-STU-104${suffix.padLeft(2, '0')}';
}
