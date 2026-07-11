import '../../core/audit/audit_logger.dart';
import 'attendance_capture_sources.dart';
import 'staff_attendance_models.dart';

/// Orchestrates a staff attendance check-in/out (B4) per the FINAL design decision:
///   1. acquire a fresh GPS fix (anti-mock, high-accuracy) — [AttendanceLocationSource];
///   2. capture a LIVE face embedding + liveness — [FaceCaptureSource];
///   3. send BOTH to the server, which is the authority on geofence + CV face match;
///   4. only on a recorded write, emit a client audit row.
///
/// Device biometric (Face ID / fingerprint) is NEVER used here — that is login-only.
/// If any step fails, NOTHING is written or audited (the buddy-punching guarantee).
/// Fully injectable so it certifies headless.
class StaffAttendanceController {
  StaffAttendanceController({
    required AttendanceLocationSource location,
    required FaceCaptureSource face,
    required StaffAttendanceWriter writer,
    required AuditLogger audit,
  })  : _location = location,
        _face = face,
        _writer = writer,
        _audit = audit;

  final AttendanceLocationSource _location;
  final FaceCaptureSource _face;
  final StaffAttendanceWriter _writer;
  final AuditLogger _audit;

  Future<StaffCheckOutcome> record(StaffCheckEvent event) async {
    // 1 + 2: device capture (location then live face). A capture failure hard-stops.
    final AttendanceLocationFix location;
    final FaceCapture face;
    try {
      location = await _location.acquire();
    } on AttendanceCaptureException catch (e) {
      return StaffCheckOutcome.locationBlocked(e.message);
    }
    // Reject an on-device mock fix before we even open the camera.
    if (location.isMock) {
      return StaffCheckOutcome.locationBlocked(
        'Mock / fake GPS detected. Turn off mock locations to record attendance.',
      );
    }
    try {
      face = await _face.capture();
    } on AttendanceCaptureException catch (e) {
      return StaffCheckOutcome.faceBlocked(e.message);
    }

    // 3 + 4: server-authoritative write, then audit only on success.
    try {
      final record = await _writer.recordCheck(event: event, location: location, face: face);
      await _audit.logTyped(
        type: event.auditType,
        metadata: {
          'eventType': event.apiValue,
          'method': record.method,
          if (record.faceMatchScore != null) 'faceMatchScore': record.faceMatchScore.toString(),
          if (record.pendingSync) 'pendingSync': 'true',
        },
      );
      return StaffCheckOutcome.recorded(record);
    } on StaffAttendanceRejected catch (e) {
      // Map the server verdict to the right banner (location vs face reason).
      return e.isFaceReason
          ? StaffCheckOutcome.faceBlocked(e.message, code: e.code)
          : StaffCheckOutcome.locationBlocked(e.message);
    } on StaffAttendanceOffline {
      // Audit R1: check-in is online-only by design — a queued event would be
      // guaranteed-stale on drain (server location-freshness window). Fail
      // honestly with a clear next step, never an optimistic "recorded".
      return StaffCheckOutcome.failed(StaffAttendanceOffline.userMessage);
    } catch (e) {
      return StaffCheckOutcome.failed(e.toString());
    }
  }
}
