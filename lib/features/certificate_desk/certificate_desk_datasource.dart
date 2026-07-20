import 'package:dio/dio.dart';

import '../../core/repositories/repository_query.dart';
import 'certificate_desk_models.dart';

/// Certificate Request Desk client datasource. Direct online Dio (raise /
/// list / detail / cancel only — approve/reject go through the EXISTING
/// generic F2 `/approvals` endpoints, not this module).
/// Endpoints (supabase/functions/_shared/certificate_desk/certificate_desk_handlers.ts):
///   POST /certificate-requests             raise
///   GET  /certificate-requests?status=     the queue
///   GET  /certificate-requests/:id         detail
///   POST /certificate-requests/:id/cancel  staff-only withdraw
class CertificateDeskDataSource {
  CertificateDeskDataSource({required Dio dio, required RepositoryQuery query})
      : _dio = dio,
        _query = query;

  final Dio _dio;
  final RepositoryQuery _query;

  Future<CertificateRequest> raise({
    required String studentId,
    required String certificateType,
    String? purpose,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/certificate-requests',
        queryParameters: _scope(),
        data: {
          'studentId': studentId,
          'certificateType': certificateType,
          if (purpose != null && purpose.trim().isNotEmpty) 'purpose': purpose.trim(),
        },
      );
      return CertificateRequest.fromJson(_inner(response.data));
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<List<CertificateRequest>> list({String? status}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/certificate-requests',
      queryParameters: {..._scope(), if (status != null) 'status': status},
    );
    final items = _inner(response.data)['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map) CertificateRequest.fromJson(item.cast<String, dynamic>()),
    ];
  }

  Future<CertificateRequest> byId(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/certificate-requests/$id',
      queryParameters: _scope(),
    );
    return CertificateRequest.fromJson(_inner(response.data));
  }

  Future<CertificateRequest> cancel(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/certificate-requests/$id/cancel',
        queryParameters: _scope(),
      );
      return CertificateRequest.fromJson(_inner(response.data));
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

  /// Maps a VALIDATION_ERROR/FORBIDDEN/CONFLICT/NOT_FOUND envelope to a typed
  /// rejection so the UI can show the real reason instead of a generic failure.
  CertificateRequestRejected? _asRejection(DioException e) {
    final status = e.response?.statusCode;
    if (status != 422 && status != 403 && status != 409 && status != 404) return null;
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final code = (error['code'] ?? '').toString();
        if (code.isNotEmpty) {
          return CertificateRequestRejected(
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

/// Raised when the server rejects a certificate-request action (bad type /
/// missing student / not-pending conflict / forbidden cancel).
class CertificateRequestRejected implements Exception {
  const CertificateRequestRejected(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'CertificateRequestRejected($code): $message';
}
