import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../dto/alumni_responses_dto.dart';
import 'alumni_api_paths.dart';

/// Dio-backed remote data source for Alumni.
class AlumniRemoteDataSource {
  AlumniRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AlumniDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AlumniApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return AlumniDashboardDto.fromJson(_responseMap(response));
  }

  Future<AlumniRegistryResponseDto> fetchRegistry({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AlumniApiPaths.registry,
      queryParameters: _queryParams(query),
    );
    return AlumniRegistryResponseDto.fromJson(_responseMap(response));
  }

  Future<AlumniDetailDto> fetchAlumniDetail({
    required RepositoryQuery query,
    required String alumniId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AlumniApiPaths.alumniDetail(alumniId),
      queryParameters: _queryParams(query),
    );
    return AlumniDetailDto.fromJson(_responseMap(response));
  }

  Future<AlumniEventsResponseDto> fetchEvents({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AlumniApiPaths.events,
      queryParameters: _queryParams(query),
    );
    return AlumniEventsResponseDto.fromJson(_responseMap(response));
  }

  Future<AlumniDonationsResponseDto> fetchDonations({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AlumniApiPaths.donations,
      queryParameters: _queryParams(query),
    );
    return AlumniDonationsResponseDto.fromJson(_responseMap(response));
  }

  Future<AlumniCampaignsResponseDto> fetchCampaigns({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AlumniApiPaths.campaigns,
      queryParameters: _queryParams(query),
    );
    return AlumniCampaignsResponseDto.fromJson(_responseMap(response));
  }

  Future<MentorshipPairsResponseDto> fetchMentorshipPairs({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AlumniApiPaths.mentorship,
      queryParameters: _queryParams(query),
    );
    return MentorshipPairsResponseDto.fromJson(_responseMap(response));
  }

  Future<AlumniReportsResponseDto> fetchReports({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AlumniApiPaths.reports,
      queryParameters: _queryParams(query),
    );
    return AlumniReportsResponseDto.fromJson(_responseMap(response));
  }

  Future<AlumniSettingsResponseDto> fetchSettings({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AlumniApiPaths.settings,
      queryParameters: _queryParams(query),
    );
    return AlumniSettingsResponseDto.fromJson(_responseMap(response));
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
    };
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }
}
