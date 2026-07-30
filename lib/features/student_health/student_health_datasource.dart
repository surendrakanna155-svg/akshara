import 'package:dio/dio.dart';

import '../../core/repositories/repository_query.dart';
import 'student_health_models.dart';

/// PRC-A Batch 2 — Student Health / Infirmary: the CLINICAL datasource.
///
/// ⚠ Owner decision #1 (LOCKED 2026-07-15): this class is the full-privilege
/// surface (health staff + explicitly authorised leadership). It must NEVER
/// be reachable from the teacher care-alert widget — that surface uses the
/// separate, narrower `CareAlertDataSource` (see care_alert/) which
/// structurally has no method that can reach a clinical endpoint.
///
/// Endpoints (supabase/functions/_shared/student_health/student_health_handlers.ts):
///   POST /student-health/incidents                          manageStudentHealth
///   GET  /student-health/incidents?studentId=                viewStudentHealthRecord
///   GET  /student-health/students/:id/record                 viewStudentHealthRecord
///   POST /student-health/care-alerts                         manageStudentHealth
///   PATCH /student-health/care-alerts/:id                    manageStudentHealth
///   POST /student-health/authorizations                      manageStudentHealth
///   POST /student-health/authorizations/:id/revoke            manageStudentHealth
///   POST /student-health/authorizations/:id/administer        administerStudentMedication
///   GET  /student-health/access-log?studentId=                viewStudentHealthRecord
///
/// ⚠ Never `debugPrint`/`print`/log any field of a parsed clinical model —
/// this datasource must stay silent on failure detail beyond the typed
/// [StudentHealthActionRejected] (whose message is the server's own static,
/// non-clinical error string — see student_health_handlers.ts header note).
class StudentHealthDataSource {
  StudentHealthDataSource({required Dio dio, required RepositoryQuery query})
      : _dio = dio,
        _query = query;

  final Dio _dio;
  final RepositoryQuery _query;

  Future<IncidentCreationResult> recordIncident({
    required String studentId,
    String? occurredAt,
    String? reportedBy,
    required String incidentType,
    required String complaintSummary,
    required String observations,
    required String treatmentGiven,
    required String outcome,
    String? referredTo,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/student-health/incidents',
        queryParameters: _scope(),
        data: {
          'studentId': studentId,
          if (occurredAt != null) 'occurredAt': occurredAt,
          if (reportedBy != null) 'reportedBy': reportedBy,
          'incidentType': incidentType,
          'complaintSummary': complaintSummary,
          'observations': observations,
          'treatmentGiven': treatmentGiven,
          'outcome': outcome,
          if (referredTo != null) 'referredTo': referredTo,
        },
      );
      return IncidentCreationResult.fromJson(_inner(response.data));
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<List<HealthIncident>> listIncidents(String studentId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/student-health/incidents',
      queryParameters: {..._scope(), 'studentId': studentId},
    );
    final raw = _inner(response.data)['incidents'];
    return [
      if (raw is List)
        for (final i in raw)
          if (i is Map) HealthIncident.fromJson(i.cast<String, dynamic>()),
    ];
  }

  Future<StudentHealthRecord> studentRecord(String studentId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/student-health/students/$studentId/record',
      queryParameters: _scope(),
    );
    return StudentHealthRecord.fromJson(_inner(response.data));
  }

  Future<CareAlert> createCareAlert({
    required String studentId,
    required String label,
    String actionNote = '',
    String severity = 'important',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/student-health/care-alerts',
        queryParameters: _scope(),
        data: {
          'studentId': studentId,
          'label': label,
          'actionNote': actionNote,
          'severity': severity,
        },
      );
      return CareAlert.fromJson(
        (_inner(response.data)['careAlert'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<CareAlert> updateCareAlert({
    required String alertId,
    String? label,
    String? actionNote,
    String? severity,
    bool? isActive,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/student-health/care-alerts/$alertId',
        queryParameters: _scope(),
        data: {
          if (label != null) 'label': label,
          if (actionNote != null) 'actionNote': actionNote,
          if (severity != null) 'severity': severity,
          if (isActive != null) 'isActive': isActive,
        },
      );
      return CareAlert.fromJson(
        (_inner(response.data)['careAlert'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<MedicationAuthorization> createAuthorization({
    required String studentId,
    required String medicationName,
    required String dosage,
    String route = 'oral',
    String scheduleNote = '',
    required String validFrom,
    String? validUntil,
    String? authorizedByGuardianId,
    required String authorizationSource,
    required String authorizationRef,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/student-health/authorizations',
        queryParameters: _scope(),
        data: {
          'studentId': studentId,
          'medicationName': medicationName,
          'dosage': dosage,
          'route': route,
          'scheduleNote': scheduleNote,
          'validFrom': validFrom,
          if (validUntil != null) 'validUntil': validUntil,
          if (authorizedByGuardianId != null) 'authorizedByGuardianId': authorizedByGuardianId,
          'authorizationSource': authorizationSource,
          'authorizationRef': authorizationRef,
        },
      );
      return MedicationAuthorization.fromJson(
        (_inner(response.data)['authorization'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<MedicationAuthorization> revokeAuthorization(String authorizationId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/student-health/authorizations/$authorizationId/revoke',
        queryParameters: _scope(),
      );
      return MedicationAuthorization.fromJson(
        (_inner(response.data)['authorization'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  /// Perm `administerStudentMedication` — a stricter, narrower gate than
  /// `manageStudentHealth`; call sites must check that permission separately.
  Future<MedicationAdministration> administerMedication({
    required String authorizationId,
    String? expectedStudentId,
    required String dosageGiven,
    String note = '',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/student-health/authorizations/$authorizationId/administer',
        queryParameters: _scope(),
        data: {
          if (expectedStudentId != null) 'studentId': expectedStudentId,
          'dosageGiven': dosageGiven,
          'note': note,
        },
      );
      return MedicationAdministration.fromJson(
        (_inner(response.data)['administration'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  Future<List<HealthAccessLogEntry>> accessLog(String studentId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/student-health/access-log',
      queryParameters: {..._scope(), 'studentId': studentId},
    );
    final raw = _inner(response.data)['entries'];
    return [
      if (raw is List)
        for (final e in raw)
          if (e is Map) HealthAccessLogEntry.fromJson(e.cast<String, dynamic>()),
    ];
  }

  Map<String, dynamic> _inner(Map<String, dynamic>? data) {
    final body = data ?? const <String, dynamic>{};
    return (body['data'] as Map<String, dynamic>?) ?? body;
  }

  /// Maps a structured domain rejection (404/409/422/403 with an
  /// `error.code`) to a typed exception carrying the server's own static,
  /// clinical-detail-free message (see student_health_handlers.ts header:
  /// error messages never interpolate a complaint/observation/diagnosis/
  /// treatment/medication name). A bare, code-less denial rethrows for the
  /// global failure mapper.
  StudentHealthActionRejected? _asRejection(DioException e) {
    final status = e.response?.statusCode;
    if (status != 422 && status != 403 && status != 404 && status != 409) return null;
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final code = (error['code'] ?? '').toString();
        if (code.isNotEmpty) {
          return StudentHealthActionRejected(
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

/// Raised when the server rejects a student-health action. The [message] is
/// always the server's own static string — never client-interpolated with
/// clinical text — so it is safe to render directly in the UI.
class StudentHealthActionRejected implements Exception {
  const StudentHealthActionRejected(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'StudentHealthActionRejected($code): $message';
}
