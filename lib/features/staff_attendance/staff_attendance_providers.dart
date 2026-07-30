import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_provider.dart';
import '../../core/network/dio_provider.dart';
import '../../core/providers/router_provider.dart';
import '../../core/reliability/reliability_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'attendance_capture_sources.dart';
import 'device/geolocator_location_source.dart';
import 'device/mlkit_face_capture.dart';
import 'face_enrollment_datasource.dart';
import 'geofence_datasource.dart';
import 'manual_request_datasource.dart';
import 'staff_attendance_controller.dart';
import 'staff_attendance_remote_datasource.dart';

/// True on the two platforms with real geolocator/camera/ML Kit/tflite plugin
/// support. Web/desktop keep the fail-loud Pending placeholders — see
/// docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §8 (device-gated residual).
/// Public (audit R1 P3) so UI entry points (FaceEnrollmentScreen) gate their
/// capture affordances with the exact same check the providers use.
bool get attendanceDeviceCaptureSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Fresh-GPS source (anti-mock, high-accuracy). Wired to the real geolocator
/// adapter on Android/iOS (Slice 3); elsewhere it fails loudly (never a silent
/// pass) — see docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §8 (device-gated residual).
final attendanceLocationSourceProvider = Provider<AttendanceLocationSource>(
  (ref) => attendanceDeviceCaptureSupported
      ? const GeolocatorLocationSource()
      : const DeviceAdapterPendingLocationSource(),
);

/// Live camera face source (embedding + liveness). Wired to the real
/// camera + ML Kit + MobileFaceNet adapter on Android/iOS (Slice 3); elsewhere
/// it fails loudly. Construction does no plugin work either way, so building
/// this provider stays safe in widget tests.
final faceCaptureSourceProvider = Provider<FaceCaptureSource>(
  (ref) => attendanceDeviceCaptureSupported
      ? MlkitFaceCaptureSource(router: () => ref.read(goRouterProvider))
      : const DeviceAdapterPendingFaceSource(),
);

/// Self-service face-enrollment datasource (Slice 3): enrol / read status /
/// revoke the CALLER's own reference face. See face_enrollment_datasource.dart.
final faceEnrollmentDataSourceProvider = Provider<FaceEnrollmentDataSource>(
  (ref) => FaceEnrollmentDataSource(
    dio: ref.watch(dioProvider),
    query: ref.watch(repositoryQueryProvider),
  ),
);

/// The school attendance geofence read/write seam — the FIRST gate of the
/// attendance chain. Until a school stores one, POST /staff-attendance/check
/// rejects every check-in with GEOFENCE_NOT_CONFIGURED, so this is the setup
/// step that turns staff attendance on.
final schoolGeofenceDataSourceProvider = Provider<SchoolGeofenceDataSource>(
  (ref) => SchoolGeofenceDataSource(
    dio: ref.watch(dioProvider),
    query: ref.watch(repositoryQueryProvider),
  ),
);

/// Client-side gate for the geofence configuration affordance.
///
/// The SERVER is the authority and enforces the exact `manageSchoolGeofence`
/// slug on PUT /staff-attendance/geofence. The client `Permission` enum carries
/// no such value, but migration 20260820000000 seeds `manageSchoolGeofence` and
/// `approveStaffAttendance` to the IDENTICAL role list in a single statement
/// (principal, vicePrincipal, schoolAdmin, hrManager, management, superAdmin,
/// organizationOwner, organizationAdmin) — so `approveStaffAttendance` is an
/// exact client-side proxy, not an approximation. Overridable in tests.
final canConfigureSchoolGeofenceProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasApprovePermission(Permission.approveStaffAttendance);
});

/// Slice 4 — the Manual Attendance Request datasource (staff submission +
/// approver queue). Same direct-Dio shape as the enrollment datasource.
final manualAttendanceRequestDataSourceProvider =
    Provider<ManualAttendanceRequestDataSource>(
  (ref) => ManualAttendanceRequestDataSource(
    dio: ref.watch(dioProvider),
    query: ref.watch(repositoryQueryProvider),
  ),
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
