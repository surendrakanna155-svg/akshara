import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_provider.dart';
import '../../core/biometric/biometric_authenticator.dart';
import '../../core/network/dio_provider.dart';
import '../../core/reliability/reliability_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import 'staff_attendance_controller.dart';
import 'staff_attendance_remote_datasource.dart';

/// Composes the staff biometric check-in controller from the app's existing DI:
/// device biometric (local_auth), the reliability write seam, and the audit log.
final staffAttendanceControllerProvider = Provider<StaffAttendanceController>((ref) {
  final writer = StaffAttendanceRemoteDataSource(
    dio: ref.watch(dioProvider),
    query: ref.watch(repositoryQueryProvider),
    reliable: ref.watch(reliableWriterProvider),
  );
  return StaffAttendanceController(
    biometric: LocalAuthBiometricAuthenticator(),
    writer: writer,
    audit: ref.watch(auditLoggerProvider),
  );
});
