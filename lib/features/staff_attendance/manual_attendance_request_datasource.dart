import 'package:dio/dio.dart';

import '../../core/repositories/repository_query.dart';
import 'manual_attendance_request_models.dart';
import 'staff_attendance_models.dart';

/// Client seam for the PRA-P0-15 audited manual-attendance fallback. Mirrors
/// [StaffAttendanceRemoteDataSource] (which posts to `/staff-attendance/check`)
/// but targets the manual-request routes. Tests inject a fake.
abstract interface class ManualAttendanceRequestDataSource {
  /// POST /staff-attendance/manual-request — raise an audited request.
  Future<ManualRequestSubmitResult> submit({
    required StaffCheckEvent event,
    required String reason,
    String? staffName,
  });

  /// GET /staff-attendance/manual-request?status=pending — the approver queue.
  Future<List<ManualAttendanceRequest>> listPending();

  /// POST /staff-attendance/manual-request/decide — approve/reject a request.
  Future<ManualRequestDecision> decide({
    required String requestId,
    required bool approve,
  });
}

/// Online Dio implementation. The manual-request write is a deliberate,
/// human-initiated fallback (not the offline-queueable check-in), so it uses a
/// direct online call rather than the reliability write seam — a queued replay
/// could double-raise a request.
class ManualAttendanceRequestRemoteDataSource
    implements ManualAttendanceRequestDataSource {
  ManualAttendanceRequestRemoteDataSource({
    required Dio dio,
    required RepositoryQuery query,
  })  : _dio = dio,
        _query = query;

  final Dio _dio;
  final RepositoryQuery _query;

  /// POST target — the singular route that RAISES a request.
  static const String _base = '/staff-attendance/manual-request';

  /// GET target — the PLURAL route that lists them. The server registers these
  /// as two distinct paths (`staff_attendance_router.ts:42-48`); there is no
  /// `GET /staff-attendance/manual-request`, so reading from [_base] 404s.
  static const String _listPath = '/staff-attendance/manual-requests';

  static const String _decidePath = '/staff-attendance/manual-request/decide';

  @override
  Future<ManualRequestSubmitResult> submit({
    required StaffCheckEvent event,
    required String reason,
    String? staffName,
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        _base,
        data: <String, dynamic>{
          'eventType': event.apiValue,
          'reason': reason,
          if (staffName != null && staffName.trim().isNotEmpty)
            'staffName': staffName.trim(),
        },
        queryParameters: _scope(),
        options: Options(method: 'POST'),
      );
      return ManualRequestSubmitResult.fromJson(_unwrap(response.data));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<List<ManualAttendanceRequest>> listPending() async {
    try {
      // No `status` filter: the server has none. Omitting `mine=true` IS the
      // request for the school's pending approval queue, and it re-gates that
      // read on `approveStaffAttendance` (`handleListManualRequests`). The
      // previous `status: 'pending'` param was never read by anything.
      final response = await _dio.request<Map<String, dynamic>>(
        _listPath,
        queryParameters: _scope(),
        options: Options(method: 'GET'),
      );
      final data = response.data?['data'];
      final rows = switch (data) {
        final List<dynamic> list => list,
        final Map<String, dynamic> map when map['items'] is List =>
          map['items'] as List<dynamic>,
        _ => const <dynamic>[],
      };
      return [
        for (final row in rows)
          ManualAttendanceRequest.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<ManualRequestDecision> decide({
    required String requestId,
    required bool approve,
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        _decidePath,
        data: <String, dynamic>{'requestId': requestId, 'approve': approve},
        queryParameters: _scope(),
        options: Options(method: 'POST'),
      );
      return ManualRequestDecision.fromJson(_unwrap(response.data));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? data) {
    final envelope = data ?? const <String, dynamic>{};
    final inner = envelope['data'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return envelope;
  }

  /// Maps a server error envelope (`{ error: { code, message } }`) to a typed
  /// [ManualAttendanceRequestException]; falls back to a network code otherwise.
  ManualAttendanceRequestException _mapError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        return ManualAttendanceRequestException(
          (error['code'] ?? 'REQUEST_FAILED').toString(),
          (error['message'] ?? 'Request failed').toString(),
        );
      }
    }
    return ManualAttendanceRequestException(
      'NETWORK',
      e.message ?? 'Could not reach the server. Check your connection.',
    );
  }

  Map<String, dynamic> _scope() => <String, dynamic>{
        'tenantId': _query.tenantId,
        if (_query.schoolId != null) 'schoolId': _query.schoolId,
        if (_query.organizationId != null)
          'organizationId': _query.organizationId,
      };
}
