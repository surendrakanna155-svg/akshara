import '../../core/audit/audit_logger.dart';
import '../../core/biometric/biometric_authenticator.dart';
import 'staff_attendance_models.dart';

/// Orchestrates a staff biometric check-in/out (O5):
///   1. prompt the device biometric (HARD-BLOCK — no PIN fallback);
///   2. only on success, record the event through the reliability write seam;
///   3. emit a client audit row.
///
/// If the biometric fails or is unavailable, NOTHING is written or audited —
/// the buddy-punching guarantee. Fully injectable so it certifies headless.
class StaffAttendanceController {
  StaffAttendanceController({
    required BiometricAuthenticator biometric,
    required StaffAttendanceWriter writer,
    required AuditLogger audit,
  })  : _biometric = biometric,
        _writer = writer,
        _audit = audit;

  final BiometricAuthenticator _biometric;
  final StaffAttendanceWriter _writer;
  final AuditLogger _audit;

  Future<StaffCheckOutcome> record(StaffCheckEvent event) async {
    final bio = await _biometric.authenticate(
      reason: 'Confirm it\'s you to ${event.label.toLowerCase()}',
    );
    if (!bio.authenticated) {
      // Hard-block: no write, no audit.
      return StaffCheckOutcome.biometricRequired(bio.message);
    }

    try {
      final record = await _writer.recordCheck(event: event, method: bio.method);
      await _audit.logTyped(
        type: event.auditType,
        metadata: {
          'eventType': event.apiValue,
          'method': bio.method,
          if (record.pendingSync) 'pendingSync': 'true',
        },
      );
      return StaffCheckOutcome.recorded(record);
    } catch (e) {
      return StaffCheckOutcome.failed(e.toString());
    }
  }
}
