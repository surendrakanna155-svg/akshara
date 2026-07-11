import '../../core/audit/audit_event.dart';

/// The two staff attendance events (B4). v1 records both with no pairing
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

/// A fresh GPS fix for an attendance event. `isMock` carries the on-device
/// mock-provider verdict; the SERVER re-validates geofence/accuracy/freshness.
class AttendanceLocationFix {
  const AttendanceLocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.isMock,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyM;
  final bool isMock;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracyM': accuracyM,
        'isMock': isMock,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
      };
}

/// A live face capture: an on-device embedding + a liveness verdict. The SERVER
/// performs the authoritative CV match against the enrolled reference — the
/// client cannot assert a match itself.
///
/// [modelTag] identifies the on-device embedder (e.g. `mobilefacenet-v1`,
/// [MobileFaceNetEmbedder.modelTag] in device/face_embedder.dart) that produced
/// [embedding]. Slice 2: when both this and the enrolled reference's model tag
/// are non-empty and differ, the server 422s FACE_EMBEDDING_MISMATCH ("re-enrol")
/// instead of silently comparing embeddings from two different model spaces.
class FaceCapture {
  const FaceCapture({
    required this.embedding,
    required this.livenessPassed,
    this.captureRef,
    this.modelTag = '',
  });

  final List<double> embedding;
  final bool livenessPassed;
  final String? captureRef;
  final String modelTag;

  Map<String, dynamic> toJson() => {
        'embedding': embedding,
        'livenessPassed': livenessPassed,
        if (captureRef != null) 'captureRef': captureRef,
        'modelTag': modelTag,
      };
}

/// A recorded (or optimistically-queued) staff check-in/out.
class StaffCheckRecord {
  const StaffCheckRecord({
    required this.id,
    required this.eventType,
    required this.method,
    this.locationVerified = false,
    this.faceMatched = false,
    this.faceMatchScore,
    this.distanceM,
    this.eventTime,
    this.pendingSync = false,
  });

  final String id;
  final String eventType;
  final String method; // 'face_match' | 'manual'
  final bool locationVerified;
  final bool faceMatched;
  final double? faceMatchScore;
  final double? distanceM;
  final String? eventTime;

  /// True when the write was queued offline (Sync Center surfaces it until confirmed).
  final bool pendingSync;

  factory StaffCheckRecord.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) => v == null ? null : (v as num).toDouble();
    return StaffCheckRecord(
      id: (json['id'] ?? '').toString(),
      eventType: (json['eventType'] ?? json['event_type'] ?? '').toString(),
      method: (json['method'] ?? 'face_match').toString(),
      locationVerified: json['locationVerified'] == true || json['location_verified'] == true,
      faceMatched: json['faceMatched'] == true || json['face_matched'] == true,
      faceMatchScore: asDouble(json['faceMatchScore'] ?? json['face_match_score']),
      distanceM: asDouble(json['distanceM'] ?? json['distance_m']),
      eventTime: (json['eventTime'] ?? json['event_time'])?.toString(),
      pendingSync: json['pendingSync'] == true,
    );
  }
}

/// Result statuses for [StaffAttendanceController.record].
///  - [locationBlocked]: geofence / mock / accuracy / stale / permission failure.
///  - [faceBlocked]: liveness fail / no-match / not-enrolled / capture cancelled.
enum StaffCheckStatus { recorded, locationBlocked, faceBlocked, failed }

class StaffCheckOutcome {
  const StaffCheckOutcome._(this.status, {this.record, this.message, this.code});

  factory StaffCheckOutcome.recorded(StaffCheckRecord record) =>
      StaffCheckOutcome._(StaffCheckStatus.recorded, record: record);

  /// Location step failed — NOTHING was written or audited.
  factory StaffCheckOutcome.locationBlocked(String? message) =>
      StaffCheckOutcome._(StaffCheckStatus.locationBlocked, message: message);

  /// Face step failed — NOTHING was written or audited. [code] carries the raw
  /// server `STAFF_ATTENDANCE_*` reason (when the block came from a server
  /// rejection) so the UI can offer a targeted fix — e.g. [isNotEnrolled].
  factory StaffCheckOutcome.faceBlocked(String? message, {String? code}) =>
      StaffCheckOutcome._(StaffCheckStatus.faceBlocked, message: message, code: code);

  factory StaffCheckOutcome.failed(String message) =>
      StaffCheckOutcome._(StaffCheckStatus.failed, message: message);

  final StaffCheckStatus status;
  final StaffCheckRecord? record;
  final String? message;
  final String? code;

  bool get isRecorded => status == StaffCheckStatus.recorded;

  /// True when the face step was blocked specifically because the staff member
  /// has no enrolled reference face yet (Slice 3 — drives the "Enrol my face"
  /// affordance on [StaffCheckInCard]).
  bool get isNotEnrolled =>
      status == StaffCheckStatus.faceBlocked &&
      code == 'STAFF_ATTENDANCE_FACE_NOT_ENROLLED';
}

/// Raised by the write seam when the SERVER rejects the attendance chain (422).
/// The [code] is the server's `STAFF_ATTENDANCE_*` code, used to pick the banner.
class StaffAttendanceRejected implements Exception {
  const StaffAttendanceRejected(this.code, this.message);
  final String code;
  final String message;

  bool get isFaceReason =>
      code.contains('FACE') || code.contains('LIVENESS');

  @override
  String toString() => 'StaffAttendanceRejected($code): $message';
}

/// The write seam for staff check-in. The real implementation routes through the
/// reliability platform (offline-queueable); tests inject a fake.
abstract interface class StaffAttendanceWriter {
  Future<StaffCheckRecord> recordCheck({
    required StaffCheckEvent event,
    required AttendanceLocationFix location,
    required FaceCapture face,
  });
}
