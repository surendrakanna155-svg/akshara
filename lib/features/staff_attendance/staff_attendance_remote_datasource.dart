import 'package:dio/dio.dart';

import '../../core/reliability/policy/operation_policy_registry.dart';
import '../../core/reliability/reliable_datasource_write.dart';
import '../../core/reliability/reliable_writer.dart';
import '../../core/repositories/repository_query.dart';
import 'staff_attendance_models.dart';

/// Real [StaffAttendanceWriter] (B4): routes the geofence+face-matched check-in
/// write through the reliability platform when a [ReliableWriter] is available;
/// otherwise a direct Dio call. EITHER WAY the write is ONLINE-ONLY (audit R1):
/// the op is registered onlineOnly because the server enforces a per-event
/// location-freshness window — a queued check-in drained later is guaranteed
/// stale, so an optimistic offline "recorded" would be a lie. Offline surfaces
/// as a typed [StaffAttendanceOffline]; there is NO optimistic/pending path.
///
/// The body carries the fresh GPS fix + the live face embedding; the SERVER is
/// the authority on geofence + CV face match. A 422 rejection is surfaced as a
/// typed [StaffAttendanceRejected] on BOTH paths: the direct-Dio path via
/// [_asRejection], and the reliability path via the failed MutationOutcome's
/// `errorCode`/`errorMessage` (the executor parses the error envelope).
class StaffAttendanceRemoteDataSource implements StaffAttendanceWriter {
  StaffAttendanceRemoteDataSource({
    required Dio dio,
    required RepositoryQuery query,
    ReliableWriter? reliable,
  })  : _dio = dio,
        _query = query,
        _reliable = reliable;

  final Dio _dio;
  final RepositoryQuery _query;
  final ReliableWriter? _reliable;

  static const String _path = '/staff-attendance/check';

  @override
  Future<StaffCheckRecord> recordCheck({
    required StaffCheckEvent event,
    required AttendanceLocationFix location,
    required FaceCapture face,
  }) async {
    final body = <String, dynamic>{
      'eventType': event.apiValue,
      'location': location.toJson(),
      'face': face.toJson(),
    };

    try {
      final reliable = _reliable;
      if (reliable == null) {
        final response = await _dio.request<Map<String, dynamic>>(
          _path,
          data: body,
          queryParameters: _scope(),
          options: Options(method: 'POST'),
        );
        final data = response.data ?? const <String, dynamic>{};
        return StaffCheckRecord.fromJson(
          (data['data'] as Map<String, dynamic>?) ?? data,
        );
      }

      final outcome = await reliable.runWrite(
        type: OperationTypes.markStaffAttendance,
        method: 'POST',
        path: _path,
        body: body,
        scope: _scope(),
        entityRef: 'staffCheckIn:${event.apiValue}',
      );

      // Typed 422 rejection (geofence / face / not-enrolled / stale …): the
      // failed outcome carries the error envelope's code+message — surface it
      // exactly like the direct-Dio path so the controller picks the right
      // banner (and the FACE_NOT_ENROLLED enrol CTA actually fires in prod).
      final code = outcome.errorCode;
      if (outcome.isFailed &&
          code != null &&
          code.startsWith('STAFF_ATTENDANCE_')) {
        throw StaffAttendanceRejected(
          code,
          outcome.errorMessage ?? 'Attendance rejected',
        );
      }
      // Online-only op + offline device → the gateway fails fast with OFFLINE.
      if (outcome.isFailed && code == 'OFFLINE') {
        throw const StaffAttendanceOffline();
      }
      // Defensive: this op is registered onlineOnly, so a pending (queued,
      // optimistic) outcome must be impossible. If a future registry change
      // ever re-queues it, refuse the guaranteed-stale optimistic success
      // rather than lie (docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §4).
      if (outcome.isPending) {
        throw const StaffAttendanceOffline();
      }

      // Remaining outcomes: confirmed → server row; conflict/other-failed →
      // the standard ApiFailureException path. The optimistic closure is
      // unreachable (pending was handled above) and must stay that way.
      final resolved = resolveWriteOutcome(
        outcome,
        optimistic: () => throw StateError(
          'staff check-in must never produce an optimistic result',
        ),
      );
      return StaffCheckRecord.fromJson(
        Map<String, dynamic>.from(resolved.data),
      );
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      // Direct-Dio fallback path: a request that never reached the server is
      // the same offline condition — same typed, honest failure.
      if (_isNetworkFailure(e)) throw const StaffAttendanceOffline();
      rethrow;
    }
  }

  /// Maps a 422 `STAFF_ATTENDANCE_*` envelope to a typed rejection; else null.
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
            (error['message'] ?? 'Attendance rejected').toString(),
          );
        }
      }
    }
    return null;
  }

  /// True when the request never reached the server (offline / DNS / timeout)
  /// — mirrors the reliability executor's network-failure classification.
  bool _isNetworkFailure(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return e.response == null && e.type != DioExceptionType.cancel;
    }
  }

  Map<String, dynamic> _scope() => {
        'tenantId': _query.tenantId,
        if (_query.schoolId != null) 'schoolId': _query.schoolId,
        if (_query.organizationId != null) 'organizationId': _query.organizationId,
      };
}
