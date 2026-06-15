import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import 'organization_builder_api_paths.dart';

class OrganizationBuilderRemoteDataSource {
  OrganizationBuilderRemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) =>
      ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();

  Map<String, dynamic> _params(RepositoryQuery query) => {
        'tenantId': query.tenantId,
        if (query.schoolId != null) 'schoolId': query.schoolId,
        if (query.organizationId != null)
          'organizationId': query.organizationId,
      };

  Future<List<Map<String, dynamic>>> fetchPacks({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      OrganizationBuilderApiPaths.packs,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchInterviewDrafts({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      OrganizationBuilderApiPaths.interviewDrafts,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchInterviewDraft({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      OrganizationBuilderApiPaths.interviewDraft(draftId),
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> saveInterviewStep({
    required RepositoryQuery query,
    required String draftId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      OrganizationBuilderApiPaths.interviewStep(draftId),
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> generatePreview({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      OrganizationBuilderApiPaths.preview,
      queryParameters: _params(query),
      data: {'draftId': draftId},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> startProvisioning({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      OrganizationBuilderApiPaths.provision,
      queryParameters: _params(query),
      data: {'draftId': draftId},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchProvisioningJob({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      OrganizationBuilderApiPaths.provisioningJob(jobId),
      queryParameters: _params(query),
    );
    return _data(response);
  }
}
