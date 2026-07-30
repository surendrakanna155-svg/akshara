import 'package:dio/dio.dart';

import '../../core/repositories/repository_query.dart';
import 'complaints_models.dart';

/// PRC-A Batch 2 — Complaints / Internal Issues client datasource. Direct
/// online Dio (no offline queueing — an SLA clock is running server-side).
/// Endpoints (supabase/functions/_shared/complaints/complaints_handlers.ts):
///   POST /complaints                    raise (raiseComplaint)
///   GET  /complaints?status=&category=&assignedTo=&severity=
///   GET  /complaints/{id}                detail + full event timeline
///   POST /complaints/{id}/assign         manageComplaints
///   POST /complaints/{id}/status         manageComplaints OR the assignee
///   POST /complaints/{id}/comment        anyone who can already see it
///   POST /complaints/{id}/vendor         manageComplaints
class ComplaintsDataSource {
  ComplaintsDataSource({required Dio dio, required RepositoryQuery query})
      : _dio = dio,
        _query = query;

  final Dio _dio;
  final RepositoryQuery _query;

  Future<Complaint> raise({
    required String category,
    required String title,
    required String description,
    String severity = 'medium',
    String? relatedStudentId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/complaints',
        queryParameters: _scope(),
        data: {
          'category': category,
          'title': title,
          'description': description,
          'severity': severity,
          if (relatedStudentId != null && relatedStudentId.isNotEmpty)
            'relatedStudentId': relatedStudentId,
        },
      );
      return Complaint.fromJson(_inner(response.data));
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<List<Complaint>> list({
    String? status,
    String? category,
    String? assignedTo,
    String? severity,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/complaints',
      queryParameters: {
        ..._scope(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (category != null && category.isNotEmpty) 'category': category,
        if (assignedTo != null && assignedTo.isNotEmpty) 'assignedTo': assignedTo,
        if (severity != null && severity.isNotEmpty) 'severity': severity,
      },
    );
    final items = _inner(response.data)['items'];
    return [
      if (items is List)
        for (final c in items)
          if (c is Map) Complaint.fromJson(c.cast<String, dynamic>()),
    ];
  }

  Future<Complaint> detail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/complaints/$id',
      queryParameters: _scope(),
    );
    return Complaint.fromJson(_inner(response.data));
  }

  Future<Complaint> assign({required String id, required String assignedTo}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/complaints/$id/assign',
        queryParameters: _scope(),
        data: {'assignedTo': assignedTo},
      );
      return Complaint.fromJson(_inner(response.data));
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  /// `resolved` REQUIRES a non-empty [resolutionNote] — the server rejects it
  /// with 422 `COMPLAINT_RESOLUTION_NOTE_REQUIRED` otherwise. Illegal
  /// transitions come back as 422 `COMPLAINT_ILLEGAL_TRANSITION`.
  Future<Complaint> updateStatus({
    required String id,
    required String status,
    String? resolutionNote,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/complaints/$id/status',
        queryParameters: _scope(),
        data: {
          'status': status,
          if (resolutionNote != null && resolutionNote.isNotEmpty)
            'resolutionNote': resolutionNote,
        },
      );
      return Complaint.fromJson(_inner(response.data));
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<ComplaintEvent> comment({required String id, required String note}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/complaints/$id/comment',
        queryParameters: _scope(),
        data: {'note': note},
      );
      return ComplaintEvent.fromJson(_inner(response.data));
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<Complaint> attachVendor({
    required String id,
    required String vendorId,
    double? repairCost,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/complaints/$id/vendor',
        queryParameters: _scope(),
        data: {
          'vendorId': vendorId,
          if (repairCost != null) 'repairCost': repairCost,
        },
      );
      return Complaint.fromJson(_inner(response.data));
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

  /// Maps a structured `COMPLAINT_*` domain rejection (422/403/404/409) or a
  /// raw `VALIDATION_ERROR` body-validation failure to a typed rejection so
  /// the UI can show the real reason (e.g. "a non-empty resolution note is
  /// required", "cannot transition from X to Y"). A generic denial (e.g. bare
  /// `FORBIDDEN` from the school-session gate) is NOT swallowed here — it
  /// rethrows for the global failure mapper to handle.
  ComplaintActionRejected? _asRejection(DioException e) {
    final status = e.response?.statusCode;
    if (status != 422 && status != 403 && status != 404 && status != 409) return null;
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final code = (error['code'] ?? '').toString();
        if (code.startsWith('COMPLAINT_') || code == 'VALIDATION_ERROR') {
          return ComplaintActionRejected(
            code,
            (error['message'] ?? 'This action was rejected').toString(),
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

/// Raised when the server rejects a complaint action (bad transition / SoD /
/// missing resolution note / vendor not found / validation).
class ComplaintActionRejected implements Exception {
  const ComplaintActionRejected(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'ComplaintActionRejected($code): $message';
}
