import 'package:dio/dio.dart';

import '../../core/repositories/repository_query.dart';
import 'gate_pass_models.dart';

/// Gate Pass / early-pickup client datasource. Direct online Dio.
/// Endpoints (supabase/functions/_shared/gate_pass/gate_pass_handlers.ts):
///   POST /gate-passes                raise (requestGatePass)
///   GET  /gate-passes?status=        the queue
///   GET  /gate-passes/:id            detail
///   POST /gate-passes/:id/verify     the gate check (verifyGatePass)
///   POST /gate-passes/:id/cancel     withdraw
///
/// The server NEVER returns the OTP/QR credential — only a `hasCredential`
/// flag — so this datasource has no way to display, request, or log one; the
/// verify screen is where staff TYPE IN the code the parent presents.
class GatePassDataSource {
  GatePassDataSource({required Dio dio, required RepositoryQuery query})
      : _dio = dio,
        _query = query;

  final Dio _dio;
  final RepositoryQuery _query;

  Future<GatePass> raise({
    required String studentId,
    required String passType,
    required String pickupPersonName,
    required String pickupPersonRelation,
    required String pickupPersonPhone,
    required DateTime scheduledAt,
    String reason = '',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/gate-passes',
        queryParameters: _scope(),
        data: {
          'studentId': studentId,
          'passType': passType,
          'reason': reason,
          'pickupPersonName': pickupPersonName,
          'pickupPersonRelation': pickupPersonRelation,
          'pickupPersonPhone': pickupPersonPhone,
          'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        },
      );
      return GatePass.fromJson(_inner(response.data));
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<List<GatePass>> list({String? status}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/gate-passes',
      queryParameters: {..._scope(), if (status != null) 'status': status},
    );
    final items = _inner(response.data)['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map) GatePass.fromJson(item.cast<String, dynamic>()),
    ];
  }

  Future<GatePass> byId(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/gate-passes/$id',
      queryParameters: _scope(),
    );
    return GatePass.fromJson(_inner(response.data));
  }

  /// The gate check: staff types in the OTP the parent presents. Failure is
  /// DELIBERATELY generic on the server (never reveals which check failed, so
  /// it cannot be used to probe pass existence) — this method surfaces a
  /// fixed, hardcoded message rather than trusting server prose to stay
  /// generic across future changes.
  Future<GatePass> verify(String id, {required String otp}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/gate-passes/$id/verify',
        queryParameters: _scope(),
        data: {'otp': otp},
      );
      return GatePass.fromJson(_inner(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final data = e.response?.data;
        final code =
            data is Map && data['error'] is Map ? (data['error']['code'] ?? '').toString() : '';
        if (code == 'GATE_PASS_VERIFICATION_FAILED') {
          throw const GatePassVerificationRejected();
        }
      }
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<GatePass> cancel(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/gate-passes/$id/cancel',
        queryParameters: _scope(),
      );
      return GatePass.fromJson(_inner(response.data));
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

  /// Maps a `GATE_PASS_*` envelope (422/403/404/409) to a typed rejection so
  /// the UI can show the real reason. Never matches the verification-failure
  /// code — that one has its own dedicated, deliberately generic exception.
  GatePassRejected? _asRejection(DioException e) {
    final status = e.response?.statusCode;
    if (status != 422 && status != 403 && status != 409 && status != 404) return null;
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final code = (error['code'] ?? '').toString();
        if (code.startsWith('GATE_PASS_') && code != 'GATE_PASS_VERIFICATION_FAILED') {
          return GatePassRejected(code, (error['message'] ?? 'Gate pass rejected').toString());
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

/// Raised when the server rejects a gate-pass action (bad type / not your
/// child / not-pending conflict / forbidden cancel). NOT used for a
/// verification failure — see [GatePassVerificationRejected].
class GatePassRejected implements Exception {
  const GatePassRejected(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'GatePassRejected($code): $message';
}

/// The gate check failed. Deliberately carries a FIXED client-side message —
/// never the server's raw text and never a reason — because the backend
/// contract is explicit that WHICH check failed (no such pass / wrong status /
/// expired / wrong code) must never be distinguishable to the caller.
class GatePassVerificationRejected implements Exception {
  const GatePassVerificationRejected();

  static const message = 'This gate pass credential is invalid, expired, or already used.';

  @override
  String toString() => 'GatePassVerificationRejected';
}
