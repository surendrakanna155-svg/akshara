import 'package:dio/dio.dart';

import '../../core/reliability/policy/operation_policy_registry.dart';
import '../../core/reliability/reliable_datasource_write.dart';
import '../../core/reliability/reliable_writer.dart';
import '../../core/repositories/repository_query.dart';
import 'staff_attendance_models.dart';

/// Real [StaffAttendanceWriter]: routes the staff check-in/out write through the
/// reliability platform (offline-queueable, exactly-once) when a [ReliableWriter]
/// is available; otherwise a direct online-only Dio call.
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
    required String method,
  }) async {
    final body = <String, dynamic>{
      'eventType': event.apiValue,
      'method': method,
      'biometricVerified': true,
    };

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
        'method': method,
        'biometricVerified': true,
        'pendingSync': true,
      },
    );
    final data = Map<String, dynamic>.from(resolved.data);
    if (resolved.pending) data['pendingSync'] = true;
    return StaffCheckRecord.fromJson(data);
  }

  Map<String, dynamic> _scope() => {
        'tenantId': _query.tenantId,
        if (_query.schoolId != null) 'schoolId': _query.schoolId,
        if (_query.organizationId != null) 'organizationId': _query.organizationId,
      };
}
