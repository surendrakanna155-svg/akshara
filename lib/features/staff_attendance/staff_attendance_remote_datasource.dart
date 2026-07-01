import 'package:dio/dio.dart';

import '../../core/reliability/policy/operation_policy_registry.dart';
import '../../core/reliability/reliable_datasource_write.dart';
import '../../core/reliability/reliable_writer.dart';
import '../../core/repositories/repository_query.dart';
import 'staff_attendance_models.dart';

/// Real [StaffAttendanceWriter] (B4): routes the geofence+face-matched check-in
/// write through the reliability platform (offline-queueable, exactly-once) when
/// a [ReliableWriter] is available; otherwise a direct online-only Dio call.
///
/// The body carries the fresh GPS fix + the live face embedding; the SERVER is the
/// authority on geofence + CV face match. A 422 rejection is surfaced as a typed
/// [StaffAttendanceRejected] so the controller can show the right reason.
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
      final resolved = resolveWriteOutcome(
        outcome,
        optimistic: () => <String, dynamic>{
          'id': 'pending_${event.apiValue}',
          'eventType': event.apiValue,
          'method': 'face_match',
          'pendingSync': true,
        },
      );
      final data = Map<String, dynamic>.from(resolved.data);
      if (resolved.pending) data['pendingSync'] = true;
      return StaffCheckRecord.fromJson(data);
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
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

  Map<String, dynamic> _scope() => {
        'tenantId': _query.tenantId,
        if (_query.schoolId != null) 'schoolId': _query.schoolId,
        if (_query.organizationId != null) 'organizationId': _query.organizationId,
      };
}
