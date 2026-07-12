import 'package:dio/dio.dart';

import '../../core/repositories/repository_query.dart';
import 'clearance_models.dart';

/// SCE-1 slice 4 — the Student Clearance / No-Dues client datasource. Direct
/// online Dio (a read report + light maker-checker writes; no offline queueing).
/// Endpoints (supabase/functions/_shared/clearance + sis_router):
///   GET  /sis/students/{id}/clearance?lifecycle=…   the consolidated report
///   POST /sis/students/{id}/clearance/waivers        maker raises a waiver
///   GET  /sis/clearance/waivers                      the approver queue
///   POST /sis/clearance/waivers/{id}/decide          checker approves/rejects
class ClearanceDataSource {
  ClearanceDataSource({required Dio dio, required RepositoryQuery query})
      : _dio = dio,
        _query = query;

  final Dio _dio;
  final RepositoryQuery _query;

  Future<ClearanceReport> report({
    required String studentId,
    String lifecycle = 'transfer_certificate',
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/sis/students/$studentId/clearance',
      queryParameters: {..._scope(), 'lifecycle': lifecycle},
    );
    return ClearanceReport.fromJson(_inner(response.data));
  }

  Future<ClearanceWaiver> raiseWaiver({
    required String studentId,
    required String reason,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sis/students/$studentId/clearance/waivers',
        queryParameters: _scope(),
        data: {'reason': reason},
      );
      return ClearanceWaiver.fromJson(_inner(response.data));
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<List<ClearanceWaiver>> pendingWaivers() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/sis/clearance/waivers',
      queryParameters: _scope(),
    );
    final items = _inner(response.data)['items'];
    return [
      if (items is List)
        for (final w in items)
          if (w is Map) ClearanceWaiver.fromJson(w.cast<String, dynamic>()),
    ];
  }

  Future<ClearanceWaiver> decideWaiver({
    required String waiverId,
    required bool approve,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sis/clearance/waivers/$waiverId/decide',
        queryParameters: _scope(),
        data: {'approve': approve},
      );
      return ClearanceWaiver.fromJson(_inner(response.data));
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  /// Revoke a stale APPROVED (un-consumed) waiver so a corrective, larger waiver
  /// can be raised when dues grew past what it covered (the deadlock escape).
  Future<ClearanceWaiver> revokeWaiver({required String waiverId}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sis/clearance/waivers/$waiverId/revoke',
        queryParameters: _scope(),
      );
      return ClearanceWaiver.fromJson(_inner(response.data));
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

  /// Maps a `CLEARANCE_WAIVER_*` envelope (422 validation / 403 SoD / 409
  /// conflicts) to a typed rejection so the UI can show the real reason.
  ClearanceWaiverRejected? _asRejection(DioException e) {
    final status = e.response?.statusCode;
    if (status != 422 && status != 403 && status != 409) return null;
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final code = (error['code'] ?? '').toString();
        if (code.startsWith('CLEARANCE_WAIVER_')) {
          return ClearanceWaiverRejected(
            code,
            (error['message'] ?? 'Waiver rejected').toString(),
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

/// Raised when the server rejects a waiver action (bad reason / SoD / conflict).
class ClearanceWaiverRejected implements Exception {
  const ClearanceWaiverRejected(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'ClearanceWaiverRejected($code): $message';
}
