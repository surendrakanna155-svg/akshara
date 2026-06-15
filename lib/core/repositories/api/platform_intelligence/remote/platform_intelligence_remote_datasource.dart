import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../dto/platform_intelligence_response_dto.dart';
import 'platform_intelligence_api_paths.dart';

class PlatformIntelligenceRemoteDataSource {
  PlatformIntelligenceRemoteDataSource(this._dio);

  final Dio _dio;

  Future<PlatformIntelligenceResponseDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformIntelligenceApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return PlatformIntelligenceResponseDto.fromJson(response.data ?? const {});
  }

  Future<PlatformIntelligenceResponseDto> fetchOrganization({
    required RepositoryQuery query,
    required String orgId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformIntelligenceApiPaths.organization,
      queryParameters: {..._queryParams(query), 'orgId': orgId},
    );
    return PlatformIntelligenceResponseDto.fromJson(response.data ?? const {});
  }

  Future<PlatformIntelligenceResponseDto> fetchComparison({
    required RepositoryQuery query,
    required List<String> schoolIds,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformIntelligenceApiPaths.compare,
      queryParameters: {
        ..._queryParams(query),
        if (schoolIds.isNotEmpty) 'schoolIds': schoolIds.join(','),
      },
    );
    return PlatformIntelligenceResponseDto.fromJson(response.data ?? const {});
  }

  Future<PlatformIntelligenceResponseDto> fetchRevenue({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformIntelligenceApiPaths.revenue,
      queryParameters: _queryParams(query),
    );
    return PlatformIntelligenceResponseDto.fromJson(response.data ?? const {});
  }

  Future<PlatformIntelligenceResponseDto> fetchGrowth({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformIntelligenceApiPaths.growth,
      queryParameters: _queryParams(query),
    );
    return PlatformIntelligenceResponseDto.fromJson(response.data ?? const {});
  }

  Future<PlatformIntelligenceResponseDto> fetchRisk({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformIntelligenceApiPaths.risk,
      queryParameters: _queryParams(query),
    );
    return PlatformIntelligenceResponseDto.fromJson(response.data ?? const {});
  }

  Future<PlatformIntelligenceResponseDto> fetchTrustDashboard({
    required RepositoryQuery query,
    required String trustId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformIntelligenceApiPaths.trustDashboard,
      queryParameters: {..._queryParams(query), 'trustId': trustId},
    );
    return PlatformIntelligenceResponseDto.fromJson(response.data ?? const {});
  }

  Future<PlatformIntelligenceResponseDto> fetchExecutiveSummary({
    required RepositoryQuery query,
    required String trustId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      PlatformIntelligenceApiPaths.executiveSummary,
      queryParameters: {..._queryParams(query), 'trustId': trustId},
    );
    return PlatformIntelligenceResponseDto.fromJson(response.data ?? const {});
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
    };
  }
}
