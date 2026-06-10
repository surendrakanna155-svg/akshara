import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../dto/analytics_intelligence_dto.dart';
import 'analytics_intelligence_api_paths.dart';

class AnalyticsIntelligenceRemoteDataSource {
  AnalyticsIntelligenceRemoteDataSource(this._dio);

  final Dio _dio;

  Future<IntelligenceDashboardMetricsDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AnalyticsIntelligenceApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return IntelligenceDashboardMetricsDto.fromJson(parseAnalyticsEnvelope(_responseMap(response)));
  }

  Future<Map<String, List<IntelligenceTrendPointDto>>> fetchTrends({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AnalyticsIntelligenceApiPaths.trends,
      queryParameters: _queryParams(query),
    );
    final data = parseAnalyticsEnvelope(_responseMap(response));
    final series = data['series'] as Map<String, dynamic>? ?? const {};
    return series.map((key, value) {
      final points = value as List<dynamic>? ?? const [];
      return MapEntry(
        key,
        points
            .map((point) => IntelligenceTrendPointDto.fromJson(point as Map<String, dynamic>))
            .toList(),
      );
    });
  }

  Future<Map<String, dynamic>> fetchRisks({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AnalyticsIntelligenceApiPaths.risks,
      queryParameters: _queryParams(query),
    );
    return parseAnalyticsEnvelope(_responseMap(response));
  }

  Future<IntelligenceSchoolHealthSummaryDto> fetchHealth({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AnalyticsIntelligenceApiPaths.health,
      queryParameters: _queryParams(query),
    );
    return IntelligenceSchoolHealthSummaryDto.fromJson(parseAnalyticsEnvelope(_responseMap(response)));
  }

  Future<List<IntelligenceRecommendationDto>> fetchRecommendations({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AnalyticsIntelligenceApiPaths.recommendations,
      queryParameters: _queryParams(query),
    );
    return parseAnalyticsItems(_responseMap(response))
        .map((item) => IntelligenceRecommendationDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<IntelligencePrincipalSummaryDto> fetchPrincipalSummary({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AnalyticsIntelligenceApiPaths.principalSummary,
      queryParameters: _queryParams(query),
    );
    return IntelligencePrincipalSummaryDto.fromJson(parseAnalyticsEnvelope(_responseMap(response)));
  }

  Future<IntelligenceWeeklyBriefingDto> fetchWeeklyBriefing({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AnalyticsIntelligenceApiPaths.weeklyBriefing,
      queryParameters: _queryParams(query),
    );
    return IntelligenceWeeklyBriefingDto.fromJson(parseAnalyticsEnvelope(_responseMap(response)));
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      if (query.page > 1) 'page': query.page,
      if (query.pageSize != 20) 'pageSize': query.pageSize,
    };
  }
}
