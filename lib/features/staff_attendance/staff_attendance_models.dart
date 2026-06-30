import '../../core/audit/audit_event.dart';

/// The two staff attendance events (O5). v1 records both with no pairing
/// enforcement and no late/grace rules.
enum StaffCheckEvent {
  checkIn,
  checkOut;

  String get apiValue => this == StaffCheckEvent.checkIn ? 'check_in' : 'check_out';

  String get label => this == StaffCheckEvent.checkIn ? 'Check in' : 'Check out';

  AuditEventType get auditType => this == StaffCheckEvent.checkIn
      ? AuditEventType.staffCheckInRecorded
      : AuditEventType.staffCheckOutRecorded;
}

/// A recorded (or optimistically-queued) staff check-in/out.
class StaffCheckRecord {
  const StaffCheckRecord({
    required this.id,
    required this.eventType,
    required this.method,
    required this.biometricVerified,
    this.eventTime,
    this.pendingSync = false,
  });

  final String id;
  final String eventType;
  final String method;
  final bool biometricVerified;
  final String? eventTime;

  /// True when the write was queued offline (Sync Center surfaces it until confirmed).
  final bool pendingSync;

  factory StaffCheckRecord.fromJson(Map<String, dynamic> json) {
    return StaffCheckRecord(
      id: (json['id'] ?? '').toString(),
      eventType: (json['eventType'] ?? json['event_type'] ?? '').toString(),
      method: (json['method'] ?? 'biometric').toString(),
      biometricVerified:
          json['biometricVerified'] == true || json['biometric_verified'] == true,
      eventTime: (json['eventTime'] ?? json['event_time'])?.toString(),
      pendingSync: json['pendingSync'] == true,
    );
  }
}

/// Result statuses for [StaffAttendanceController.record].
enum StaffCheckStatus { recorded, biometricRequired, failed }

class StaffCheckOutcome {
  const StaffCheckOutcome._(this.status, {this.record, this.message});

  factory StaffCheckOutcome.recorded(StaffCheckRecord record) =>
      StaffCheckOutcome._(StaffCheckStatus.recorded, record: record);

  /// Biometric did not verify — NOTHING was written or audited (hard-block).
  factory StaffCheckOutcome.biometricRequired(String? message) =>
      StaffCheckOutcome._(StaffCheckStatus.biometricRequired, message: message);

  factory StaffCheckOutcome.failed(String message) =>
      StaffCheckOutcome._(StaffCheckStatus.failed, message: message);

  final StaffCheckStatus status;
  final StaffCheckRecord? record;
  final String? message;

  bool get isRecorded => status == StaffCheckStatus.recorded;
}

/// The write seam for staff check-in. The real implementation routes through the
/// reliability platform (offline-queueable); tests inject a fake.
abstract interface class StaffAttendanceWriter {
  Future<StaffCheckRecord> recordCheck({
    required StaffCheckEvent event,
    required String method,
  });
}
