import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../continuity_api_paths.dart';
import '../dto/continuity_request_dto.dart';
import '../dto/continuity_response_dto.dart';

class ContinuityRemoteDataSource {
  ContinuityRemoteDataSource(this._dio);

  final Dio _dio;

  Future<ContinuityMigrationPlanDto> previewMigration({
    required RepositoryQuery query,
    required ContinuityPreviewRequestDto request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ContinuityApiPaths.preview,
      queryParameters: _query(query),
      data: request.toJson(),
    );
    return ContinuityMigrationPlanDto.fromJson(_requireData(response));
  }

  Future<ContinuityMigrationResultDto> executeMigration({
    required RepositoryQuery query,
    required String planId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ContinuityApiPaths.execute(planId),
      queryParameters: _query(query),
    );
    return ContinuityMigrationResultDto.fromJson(_requireData(response));
  }

  Future<Map<String, dynamic>> transferMessageOwnership({
    required RepositoryQuery query,
    required String fromTeacherId,
    required String toTeacherId,
    required List<String> studentIds,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ContinuityApiPaths.messageOwnership,
      queryParameters: _query(query),
      data: {
        'fromTeacherId': fromTeacherId,
        'toTeacherId': toTeacherId,
        'studentIds': studentIds,
      },
    );
    return _requireData(response);
  }

  Future<Map<String, dynamic>> migrateTimetableSlots({
    required RepositoryQuery query,
    required String studentId,
    required String fromSection,
    required String toSection,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ContinuityApiPaths.timetable,
      queryParameters: _query(query),
      data: {
        'studentId': studentId,
        'fromSection': fromSection,
        'toSection': toSection,
      },
    );
    return _requireData(response);
  }

  Future<Map<String, dynamic>> migrateParentNotifications({
    required RepositoryQuery query,
    required String studentId,
    required List<String> parentIds,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ContinuityApiPaths.parentNotifications,
      queryParameters: _query(query),
      data: {
        'studentId': studentId,
        'parentIds': parentIds,
      },
    );
    return _requireData(response);
  }

  Future<Map<String, dynamic>> migrateHomeworkAssignments({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ContinuityApiPaths.homework,
      queryParameters: _query(query),
      data: {'studentId': studentId},
    );
    return _requireData(response);
  }

  Future<ContinuityAuditTrailDto> fetchAuditTrail({
    required RepositoryQuery query,
    required String migrationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ContinuityApiPaths.auditTrail(migrationId),
      queryParameters: _query(query),
    );
    return ContinuityAuditTrailDto.fromJson(_responseMap(response));
  }

  Map<String, dynamic> _query(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
    };
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(_responseMap(response)).requireData();
  }
}
