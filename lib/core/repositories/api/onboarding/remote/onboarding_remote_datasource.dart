import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../dto/onboarding_dto.dart';
import 'onboarding_api_paths.dart';

class OnboardingRemoteDataSource {
  OnboardingRemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, String> _queryParams(RepositoryQuery query) {
    final params = <String, String>{};
    final orgId = query.organizationId;
    final schoolId = query.schoolId;
    if (orgId != null && orgId.isNotEmpty) params['organizationId'] = orgId;
    if (schoolId != null && schoolId.isNotEmpty) params['schoolId'] = schoolId;
    return params;
  }

  Future<OnboardingDashboardDto> fetchDashboard({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      OnboardingApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return OnboardingDashboardDto.fromJson(_responseMap(response));
  }

  Future<OnboardingImportPreviewDto> previewStudentImport({
    required RepositoryQuery query,
    required String fileName,
    required List<Map<String, dynamic>> rows,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      OnboardingApiPaths.studentPreview,
      data: {'fileName': fileName, 'rows': rows},
      queryParameters: _queryParams(query),
    );
    return OnboardingImportPreviewDto.fromJson(_responseMap(response));
  }

  Future<OnboardingImportPreviewDto> previewTeacherImport({
    required RepositoryQuery query,
    required String fileName,
    required List<Map<String, dynamic>> rows,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      OnboardingApiPaths.teacherPreview,
      data: {'fileName': fileName, 'rows': rows},
      queryParameters: _queryParams(query),
    );
    return OnboardingImportPreviewDto.fromJson(_responseMap(response));
  }

  Future<OnboardingImportJobDto> commitImport({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      OnboardingApiPaths.commitImport(jobId),
      queryParameters: _queryParams(query),
    );
    return OnboardingImportJobDto.fromJson(_responseMap(response));
  }

  Future<OnboardingImportJobDto> rollbackImport({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      OnboardingApiPaths.rollbackImport(jobId),
      queryParameters: _queryParams(query),
    );
    return OnboardingImportJobDto.fromJson(_responseMap(response));
  }

  Future<OnboardingInvitesListDto> fetchInvites({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      OnboardingApiPaths.invites,
      queryParameters: _queryParams(query),
    );
    return OnboardingInvitesListDto.fromJson(_responseMap(response));
  }

  Future<OnboardingInviteDto> createInvite({
    required RepositoryQuery query,
    required String inviteType,
    required String recipientPhone,
    required String recipientLabel,
    String? studentId,
    String channel = 'whatsapp',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      OnboardingApiPaths.invites,
      data: {
        'inviteType': inviteType,
        'recipientPhone': recipientPhone,
        'recipientLabel': recipientLabel,
        if (studentId != null) 'studentId': studentId,
        'channel': channel,
      },
      queryParameters: _queryParams(query),
    );
    return OnboardingInviteDto.fromJson(_responseMap(response));
  }
}
