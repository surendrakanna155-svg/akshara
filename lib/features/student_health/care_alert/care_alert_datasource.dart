import 'package:dio/dio.dart';

import '../../../core/repositories/repository_query.dart';
import '../student_health_models.dart';

/// PRC-A Batch 2 — the TEACHER-SAFE datasource.
///
/// Owner decision #1 (LOCKED 2026-07-15): this class has EXACTLY ONE method,
/// hitting EXACTLY ONE endpoint (`GET /student-health/students/:id/care-alert`,
/// perm `viewStudentCareAlert`). It is deliberately narrower than
/// [StudentHealthDataSource] — a teaching role's widget is wired to this
/// class, not that one, so it is structurally incapable of reaching a
/// clinical route (incidents / full record / authorizations / access log)
/// even by mistake. Do NOT add methods here; anything clinical belongs on
/// `StudentHealthDataSource` in the parent directory instead.
class CareAlertDataSource {
  CareAlertDataSource({required Dio dio, required RepositoryQuery query})
      : _dio = dio,
        _query = query;

  final Dio _dio;
  final RepositoryQuery _query;

  Future<List<CareAlert>> fetch(String studentId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/student-health/students/$studentId/care-alert',
      queryParameters: _scope(),
    );
    final body = response.data ?? const <String, dynamic>{};
    final inner = (body['data'] as Map<String, dynamic>?) ?? body;
    final raw = inner['careAlerts'];
    return [
      if (raw is List)
        for (final a in raw)
          if (a is Map) CareAlert.fromJson(a.cast<String, dynamic>()),
    ];
  }

  Map<String, dynamic> _scope() => {
        'tenantId': _query.tenantId,
        if (_query.schoolId != null) 'schoolId': _query.schoolId,
        if (_query.organizationId != null) 'organizationId': _query.organizationId,
      };
}
