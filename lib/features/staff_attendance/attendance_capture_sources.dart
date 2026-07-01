import 'staff_attendance_models.dart';

/// B4 — the two device capture seams for staff attendance auth.
///
/// Per docs/ATTENDANCE_AUTH_DESIGN_DECISION.md (FINAL): attendance is proven by a
/// GPS geofence fix + anti-mock validation + a LIVE camera face (server-side CV
/// match). Device biometric (Face ID / fingerprint) is NEVER used here — it is
/// login-only. Both seams are injected so the controller certifies headless with
/// fakes; the real geolocator / camera+ML adapters are wired on a device build.

/// Which capture step failed — drives the right user-facing message.
enum AttendanceCaptureStep { location, face }

class AttendanceCaptureException implements Exception {
  const AttendanceCaptureException(this.step, this.code, this.message);
  final AttendanceCaptureStep step;
  final String code;
  final String message;

  bool get isLocation => step == AttendanceCaptureStep.location;

  @override
  String toString() => 'AttendanceCaptureException($code): $message';
}

/// Acquires a fresh, high-accuracy GPS fix with mock-provider detection.
/// Throws [AttendanceCaptureException] (step=location) when location services are
/// off, permission is denied, or no usable fix is available.
abstract interface class AttendanceLocationSource {
  Future<AttendanceLocationFix> acquire();
}

/// Captures a LIVE face and extracts an embedding + a liveness verdict on-device.
/// Throws [AttendanceCaptureException] (step=face) when there is no camera, the
/// user cancels, or liveness cannot be established.
abstract interface class FaceCaptureSource {
  Future<FaceCapture> capture();
}

// ── Test/headless fakes ──────────────────────────────────────────────────────

class FixedLocationSource implements AttendanceLocationSource {
  const FixedLocationSource(this.fix);
  final AttendanceLocationFix fix;
  @override
  Future<AttendanceLocationFix> acquire() async => fix;
}

class FailingLocationSource implements AttendanceLocationSource {
  const FailingLocationSource([this.code = 'LOCATION_UNAVAILABLE', this.message = 'Turn on location to check in']);
  final String code;
  final String message;
  @override
  Future<AttendanceLocationFix> acquire() async =>
      throw AttendanceCaptureException(AttendanceCaptureStep.location, code, message);
}

class FixedFaceSource implements FaceCaptureSource {
  const FixedFaceSource(this.face);
  final FaceCapture face;
  @override
  Future<FaceCapture> capture() async => face;
}

class FailingFaceSource implements FaceCaptureSource {
  const FailingFaceSource([this.code = 'FACE_CAPTURE_CANCELLED', this.message = 'Face capture was cancelled']);
  final String code;
  final String message;
  @override
  Future<FaceCapture> capture() async =>
      throw AttendanceCaptureException(AttendanceCaptureStep.face, code, message);
}

/// Placeholder wired into providers until the geolocator / camera+ML adapters are
/// added on a device build. It fails loudly (never silently passes) so a missing
/// device integration can never be mistaken for a successful capture.
class DeviceAdapterPendingLocationSource implements AttendanceLocationSource {
  const DeviceAdapterPendingLocationSource();
  @override
  Future<AttendanceLocationFix> acquire() async => throw const AttendanceCaptureException(
        AttendanceCaptureStep.location,
        'DEVICE_ADAPTER_PENDING',
        'Location capture is not available in this build.',
      );
}

class DeviceAdapterPendingFaceSource implements FaceCaptureSource {
  const DeviceAdapterPendingFaceSource();
  @override
  Future<FaceCapture> capture() async => throw const AttendanceCaptureException(
        AttendanceCaptureStep.face,
        'DEVICE_ADAPTER_PENDING',
        'Camera face capture is not available in this build.',
      );
}
