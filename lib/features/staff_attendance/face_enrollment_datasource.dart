import 'package:dio/dio.dart';

import '../../core/repositories/repository_query.dart';

/// The caller's own active face-enrollment summary (GET
/// /attendance-auth/face/enrollment). The embedding vector is NEVER returned —
/// see supabase/functions/_shared/attendance_auth/face_enrollment_handlers.ts.
class FaceEnrollmentStatus {
  const FaceEnrollmentStatus({
    required this.enrolled,
    this.modelTag,
    this.enrolledAt,
  });

  final bool enrolled;
  final String? modelTag;
  final DateTime? enrolledAt;

  factory FaceEnrollmentStatus.fromJson(Map<String, dynamic> json) {
    final enrolledAtRaw = json['enrolledAt'];
    return FaceEnrollmentStatus(
      enrolled: json['enrolled'] == true,
      modelTag: (json['modelTag'] as String?)?.isNotEmpty == true
          ? json['modelTag'] as String
          : null,
      enrolledAt: enrolledAtRaw == null
          ? null
          : DateTime.tryParse(enrolledAtRaw.toString()),
    );
  }

  static const FaceEnrollmentStatus notEnrolled =
      FaceEnrollmentStatus(enrolled: false);
}

/// The result of a successful enrol/re-enrol (POST /staff-attendance/enroll-face).
class FaceEnrollmentResult {
  const FaceEnrollmentResult({
    required this.id,
    required this.modelTag,
    required this.enrolledAt,
  });

  final String id;
  final String modelTag;
  final DateTime? enrolledAt;

  factory FaceEnrollmentResult.fromJson(Map<String, dynamic> json) {
    final enrolledAtRaw = json['enrolledAt'];
    return FaceEnrollmentResult(
      id: (json['id'] ?? '').toString(),
      modelTag: (json['modelTag'] ?? '').toString(),
      enrolledAt: enrolledAtRaw == null
          ? null
          : DateTime.tryParse(enrolledAtRaw.toString()),
    );
  }
}

/// Raised when the SERVER rejects an enrol/revoke call (422/404). [code] is the
/// raw `STAFF_ATTENDANCE_*` / `ATTENDANCE_AUTH_*` code — see
/// [faceEnrollmentFriendlyMessage] for the UI-facing mapping.
class FaceEnrollmentRejected implements Exception {
  const FaceEnrollmentRejected(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'FaceEnrollmentRejected($code): $message';
}

/// Maps a [FaceEnrollmentRejected.code] to a friendly, actionable message.
/// Falls back to the server's own message for any code this client doesn't
/// have a bespoke copy for.
String faceEnrollmentFriendlyMessage(FaceEnrollmentRejected rejected) {
  switch (rejected.code) {
    case 'STAFF_ATTENDANCE_EMBEDDING_REQUIRED':
    case 'ATTENDANCE_AUTH_EMBEDDING_REQUIRED':
      return "We couldn't read your face clearly. Face the camera in good light and try again.";
    case 'STAFF_ATTENDANCE_EMBEDDING_DIMS_INVALID':
    case 'ATTENDANCE_AUTH_EMBEDDING_DIMS_INVALID':
      return "This device's face model isn't compatible. Contact your admin.";
    case 'STAFF_ATTENDANCE_EMBEDDING_INVALID':
    case 'ATTENDANCE_AUTH_EMBEDDING_INVALID':
      return 'That face capture was not valid. Try enrolling again.';
    case 'ATTENDANCE_AUTH_NOT_ENROLLED':
      return 'You have no face enrolled yet.';
    default:
      return rejected.message;
  }
}

/// Face enrollment write/read datasource (Slice 3 self-service flow):
///   POST /staff-attendance/enroll-face      enrol/replace OWN reference face
///   GET  /attendance-auth/face/enrollment   read OWN enrollment status
///   POST /attendance-auth/face/revoke       revoke OWN reference face
///
/// Same envelope/scope conventions as [StaffAttendanceRemoteDataSource]
/// (`staff_attendance_remote_datasource.dart`): a direct online-only Dio call,
/// scoped by tenant/school/organization query params — enrollment is a rare,
/// deliberate action (not offline-queueable like the check-in write).
class FaceEnrollmentDataSource {
  FaceEnrollmentDataSource({required Dio dio, required RepositoryQuery query})
      : _dio = dio,
        _query = query;

  final Dio _dio;
  final RepositoryQuery _query;

  static const String _enrollPath = '/staff-attendance/enroll-face';
  static const String _statusPath = '/attendance-auth/face/enrollment';
  static const String _revokePath = '/attendance-auth/face/revoke';

  Future<FaceEnrollmentResult> enroll({
    required List<double> embedding,
    String modelTag = '',
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        _enrollPath,
        data: <String, dynamic>{
          'embedding': embedding,
          'modelTag': modelTag,
        },
        queryParameters: _scope(),
        options: Options(method: 'POST'),
      );
      final data = response.data ?? const <String, dynamic>{};
      return FaceEnrollmentResult.fromJson(
        (data['data'] as Map<String, dynamic>?) ?? data,
      );
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<FaceEnrollmentStatus> status() async {
    final response = await _dio.request<Map<String, dynamic>>(
      _statusPath,
      queryParameters: _scope(),
      options: Options(method: 'GET'),
    );
    final data = response.data ?? const <String, dynamic>{};
    return FaceEnrollmentStatus.fromJson(
      (data['data'] as Map<String, dynamic>?) ?? data,
    );
  }

  /// Returns true when an active enrollment was revoked; false when there was
  /// none to revoke (server 404 ATTENDANCE_AUTH_NOT_ENROLLED).
  Future<bool> revoke() async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        _revokePath,
        queryParameters: _scope(),
        options: Options(method: 'POST'),
      );
      final data = response.data ?? const <String, dynamic>{};
      final inner = (data['data'] as Map<String, dynamic>?) ?? data;
      return inner['revoked'] == true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  /// Maps a 422 error envelope to a typed rejection; else null.
  FaceEnrollmentRejected? _asRejection(DioException e) {
    if (e.response?.statusCode != 422) return null;
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final code = (error['code'] ?? '').toString();
        if (code.isNotEmpty) {
          return FaceEnrollmentRejected(
            code,
            (error['message'] ?? 'Enrollment rejected').toString(),
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
