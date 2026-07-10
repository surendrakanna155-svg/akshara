// Adaptive AI (P3-AI-2 / W2) — Dio remote datasource. GETs the feeds / quick
// actions / search; POSTs recommendation feedback. Envelope-parsed; Dio errors
// are already mapped to ApiFailureException by the interceptor chain.

import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../dto/adaptive_ai_dto.dart';
import 'adaptive_ai_api_paths.dart';

class AdaptiveAiRemoteDataSource {
  AdaptiveAiRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AdaptiveFeedDto> fetchPriorityFeed({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdaptiveAiApiPaths.priorities,
      queryParameters: {
        ..._queryParams(query),
        'persona': persona,
        if (limit != null) 'limit': limit,
      },
    );
    return AdaptiveFeedDto.fromEnvelopeData(parseAdaptiveEnvelope(_responseMap(response)));
  }

  Future<AdaptiveFeedDto> fetchRecommendations({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdaptiveAiApiPaths.recommendations,
      queryParameters: {
        ..._queryParams(query),
        'persona': persona,
        if (limit != null) 'limit': limit,
      },
    );
    return AdaptiveFeedDto.fromEnvelopeData(parseAdaptiveEnvelope(_responseMap(response)));
  }

  Future<void> sendFeedback({
    required RepositoryQuery query,
    required String itemKey,
    required String itemType,
    required String action,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      AdaptiveAiApiPaths.recommendationFeedback,
      queryParameters: _queryParams(query),
      data: {'itemKey': itemKey, 'itemType': itemType, 'action': action},
    );
  }

  Future<List<AdaptiveQuickActionDto>> fetchQuickActions({
    required RepositoryQuery query,
    required String persona,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdaptiveAiApiPaths.quickActions,
      queryParameters: {..._queryParams(query), 'persona': persona},
    );
    return parseQuickActions(parseAdaptiveEnvelope(_responseMap(response)));
  }

  Future<UniversalSearchResultDto> search({
    required RepositoryQuery query,
    required String term,
    int? limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdaptiveAiApiPaths.search,
      queryParameters: {
        ..._queryParams(query),
        'q': term,
        if (limit != null) 'limit': limit,
      },
    );
    return UniversalSearchResultDto.fromEnvelopeData(parseAdaptiveEnvelope(_responseMap(response)));
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
