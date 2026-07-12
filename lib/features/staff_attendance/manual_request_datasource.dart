import 'package:dio/dio.dart';

import '../../core/repositories/repository_query.dart';
import 'staff_attendance_models.dart';

/// P1-PROD-22 slice 4 — the Manual Attendance Request flow: the design's ONLY
/// sanctioned fallback when the geofence + live-face chain cannot complete
/// (docs/ATTENDANCE_AUTH_DESIGN_DECISION.md). Direct online Dio (the request
/// itself is a lightweight audited record — no offline queueing; if the staff
/// member is offline they retry when back online, exactly like check-in).
///
/// Server contract (`/staff-attendance/*`):
///  - POST  manual-request                {eventType, reason} → {id, status, eventType}
///  - GET   manual-requests?mine=true     own recent requests (JWT subject)
///  - GET   manual-requests               pending queue (approveStaffAttendance)
///  - POST  manual-request/decide         {requestId, approve} → {id, status, checkInId}
class ManualAttendanceRequestDataSource {
  ManualAttendanceRequestDataSource({
    required Dio dio,
    required RepositoryQuery query,
  })  : _dio = dio,
        _query = query;

  final Dio _dio;
  final RepositoryQuery _query;

  static const String _base = '/staff-attendance';

  Future<ManualAttendanceRequest> create({
    required StaffCheckEvent event,
    required String reason,
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        '$_base/manual-request',
        data: {'eventType': event.apiValue, 'reason': reason},
        queryParameters: _scope(),
        options: Options(method: 'POST'),
      );
      return ManualAttendanceRequest.fromJson(_inner(response.data));
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  /// The caller's own recent requests (server scopes to the JWT subject).
  Future<List<ManualAttendanceRequest>> myRequests() async {
    final response = await _dio.request<Map<String, dynamic>>(
      '$_base/manual-requests',
      queryParameters: {..._scope(), 'mine': 'true'},
      options: Options(method: 'GET'),
    );
    final items = _inner(response.data)['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map)
            ManualAttendanceRequest.fromJson(item.cast<String, dynamic>()),
    ];
  }

  /// The school's pending approval queue (approveStaffAttendance-gated).
  Future<List<PendingManualRequest>> pendingQueue() async {
    final response = await _dio.request<Map<String, dynamic>>(
      '$_base/manual-requests',
      queryParameters: _scope(),
      options: Options(method: 'GET'),
    );
    final items = _inner(response.data)['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map)
            PendingManualRequest.fromJson(item.cast<String, dynamic>()),
    ];
  }

  Future<void> decide({required String requestId, required bool approve}) async {
    try {
      await _dio.request<Map<String, dynamic>>(
        '$_base/manual-request/decide',
        data: {'requestId': requestId, 'approve': approve},
        queryParameters: _scope(),
        options: Options(method: 'POST'),
      );
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Map<String, dynamic> _inner(Map<String, dynamic>? data) {
    final body = data ?? const <String, dynamic>{};
    return (body['data'] as Map<String, dynamic>?) ?? body;
  }

  /// Maps a 422 `STAFF_ATTENDANCE_*` envelope (bad reason / not-found request)
  /// to the same typed rejection the check-in datasource uses.
  StaffAttendanceRejected? _asRejection(DioException e) {
    if (e.response?.statusCode != 422) return null;
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final code = (error['code'] ?? '').toString();
        if (code.startsWith('STAFF_ATTENDANCE_')) {
          return StaffAttendanceRejected(
            code,
            (error['message'] ?? 'Request rejected').toString(),
          );
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _scope() => {
        'tenantId': _query.tenantId,
        if (_query.schoolId != null) 'schoolId': _query.schoolId,
        if (_query.organizationId != null) 'organizationId': _query.organizationId,
      };
}

/// One of the caller's own manual attendance requests.
class ManualAttendanceRequest {
  const ManualAttendanceRequest({
    required this.id,
    required this.eventType,
    required this.status,
    this.reason = '',
    this.createdAt,
    this.decidedAt,
  });

  final String id;
  final String eventType; // 'check_in' | 'check_out'
  final String status; // 'pending' | 'approved' | 'rejected'
  final String reason;
  final String? createdAt;
  final String? decidedAt;

  bool get isPending => status == 'pending';

  factory ManualAttendanceRequest.fromJson(Map<String, dynamic> json) {
    return ManualAttendanceRequest(
      id: (json['id'] ?? '').toString(),
      eventType: (json['eventType'] ?? json['event_type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? json['created_at'])?.toString(),
      decidedAt: (json['decidedAt'] ?? json['decided_at'])?.toString(),
    );
  }
}

/// One pending request in the approver queue.
class PendingManualRequest {
  const PendingManualRequest({
    required this.id,
    required this.staffName,
    required this.eventType,
    required this.reason,
    this.createdAt,
  });

  final String id;
  final String staffName;
  final String eventType;
  final String reason;
  final String? createdAt;

  factory PendingManualRequest.fromJson(Map<String, dynamic> json) {
    return PendingManualRequest(
      id: (json['id'] ?? '').toString(),
      staffName: (json['staffName'] ?? json['staff_name'] ?? '').toString(),
      eventType: (json['eventType'] ?? json['event_type'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? json['created_at'])?.toString(),
    );
  }
}
