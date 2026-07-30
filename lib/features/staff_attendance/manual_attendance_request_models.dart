import 'staff_attendance_models.dart';

/// PRA-P0-15 — the AUDITED manual-attendance fallback (GA-2). When device
/// capture (GPS geofence + live face) is unavailable, a staff member raises an
/// audited manual request; a holder of `approveStaffAttendance` decides it and,
/// on approve, the server mints a real check-in. Backend contract:
///   POST /staff-attendance/manual-request         { eventType, reason(>=3), staffName? }
///   POST /staff-attendance/manual-request/decide   { requestId, approve }
/// Both return the standard `{ data, error }` envelope.

/// Lifecycle of a manual attendance request (mirrors the server CHECK constraint
/// `status IN ('pending','approved','rejected')`).
enum ManualRequestStatus {
  pending,
  approved,
  rejected;

  static ManualRequestStatus fromApi(String? value) => switch (value) {
        'approved' => ManualRequestStatus.approved,
        'rejected' => ManualRequestStatus.rejected,
        _ => ManualRequestStatus.pending,
      };

  String get label => switch (this) {
        ManualRequestStatus.pending => 'Pending',
        ManualRequestStatus.approved => 'Approved',
        ManualRequestStatus.rejected => 'Rejected',
      };

  bool get isPending => this == ManualRequestStatus.pending;
}

StaffCheckEvent staffCheckEventFromApi(String? value) =>
    value == 'check_out' ? StaffCheckEvent.checkOut : StaffCheckEvent.checkIn;

/// A manual attendance request row (table `staff_attendance_requests`).
class ManualAttendanceRequest {
  const ManualAttendanceRequest({
    required this.id,
    required this.status,
    required this.eventType,
    this.reason = '',
    this.staffName = '',
    this.userId = '',
    this.createdAt,
  });

  final String id;
  final ManualRequestStatus status;
  final StaffCheckEvent eventType;
  final String reason;
  final String staffName;
  final String userId;
  final DateTime? createdAt;

  factory ManualAttendanceRequest.fromJson(Map<String, dynamic> json) {
    return ManualAttendanceRequest(
      id: (json['id'] ?? '').toString(),
      status: ManualRequestStatus.fromApi(json['status']?.toString()),
      eventType:
          staffCheckEventFromApi((json['eventType'] ?? json['event_type'])?.toString()),
      reason: (json['reason'] ?? '').toString(),
      staffName: (json['staffName'] ?? json['staff_name'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}

/// Result of POST /staff-attendance/manual-request (`{ id, status, eventType }`).
class ManualRequestSubmitResult {
  const ManualRequestSubmitResult({
    required this.id,
    required this.status,
    required this.eventType,
  });

  final String id;
  final ManualRequestStatus status;
  final StaffCheckEvent eventType;

  factory ManualRequestSubmitResult.fromJson(Map<String, dynamic> json) {
    return ManualRequestSubmitResult(
      id: (json['id'] ?? '').toString(),
      status: ManualRequestStatus.fromApi(json['status']?.toString()),
      eventType:
          staffCheckEventFromApi((json['eventType'] ?? json['event_type'])?.toString()),
    );
  }
}

/// Result of POST /staff-attendance/manual-request/decide
/// (`{ id, status, checkInId }` — `checkInId` non-null when approved).
class ManualRequestDecision {
  const ManualRequestDecision({
    required this.id,
    required this.status,
    this.checkInId,
  });

  final String id;
  final ManualRequestStatus status;
  final String? checkInId;

  bool get isApproved => status == ManualRequestStatus.approved;

  factory ManualRequestDecision.fromJson(Map<String, dynamic> json) {
    final checkIn = json['checkInId'] ?? json['check_in_id'];
    return ManualRequestDecision(
      id: (json['id'] ?? '').toString(),
      status: ManualRequestStatus.fromApi(json['status']?.toString()),
      checkInId: checkIn?.toString(),
    );
  }
}

/// Raised when the server rejects a manual-request call. Carries the server
/// `STAFF_ATTENDANCE_*` code (e.g. `STAFF_ATTENDANCE_REASON_REQUIRED`) so the UI
/// can surface the precise reason.
class ManualAttendanceRequestException implements Exception {
  const ManualAttendanceRequestException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'ManualAttendanceRequestException($code): $message';
}
