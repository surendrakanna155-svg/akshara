import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_provider.dart';
import '../../core/network/dio_provider.dart';
import '../../core/reliability/reliability_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import 'attendance_capture_sources.dart';
import 'staff_attendance_controller.dart';
import 'staff_attendance_remote_datasource.dart';

/// Fresh-GPS source (anti-mock, high-accuracy). The concrete geolocator adapter is
/// wired on a device build; until then it fails loudly (never a silent pass) —
/// see docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §8 (device-gated residual).
final attendanceLocationSourceProvider = Provider<AttendanceLocationSource>(
  (ref) => const DeviceAdapterPendingLocationSource(),
);

/// Live camera face source (embedding + liveness). The concrete camera+ML adapter
/// is wired on a device build; until then it fails loudly.
final faceCaptureSourceProvider = Provider<FaceCaptureSource>(
  (ref) => const DeviceAdapterPendingFaceSource(),
);

/// Composes the staff attendance controller (B4): GPS geofence + live camera face
/// (server-authoritative CV match) + the reliability write seam + the audit log.
/// NO device biometric — that mechanism is login-only per the FINAL design decision.
final staffAttendanceControllerProvider = Provider<StaffAttendanceController>((ref) {
  final writer = StaffAttendanceRemoteDataSource(
    dio: ref.watch(dioProvider),
    query: ref.watch(repositoryQueryProvider),
    reliable: ref.watch(reliableWriterProvider),
  );
  return StaffAttendanceController(
    location: ref.watch(attendanceLocationSourceProvider),
    face: ref.watch(faceCaptureSourceProvider),
    writer: writer,
    audit: ref.watch(auditLoggerProvider),
  );
});
