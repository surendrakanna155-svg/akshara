import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../../../../features/copilot/copilot_models.dart';
import '../../../../../features/copilot/copilot_screen_context.dart';
import '../dto/copilot_dto.dart';
import 'copilot_api_paths.dart';

class CopilotRemoteDataSource {
  CopilotRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<CopilotAssistantDto>> fetchAssistants({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      CopilotApiPaths.assistants,
      queryParameters: _queryParams(query),
    );
    return parseCopilotItems(_responseMap(response))
        .map(CopilotAssistantDto.fromJson)
        .toList();
  }

  Future<CopilotSuggestionsDto> fetchSuggestions({
    required RepositoryQuery query,
    required CopilotAssistantType assistantType,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      CopilotApiPaths.suggestions,
      queryParameters: {
        ..._queryParams(query),
        'assistant': assistantType.name,
      },
    );
    return CopilotSuggestionsDto.fromJson(parseCopilotEnvelope(_responseMap(response)));
  }

  /// The N10 AI cost panel: month-to-date spend vs cap, calls by outcome /
  /// surface, and cache hit ratio (RBAC viewAiCopilot; school-scoped).
  Future<AiEconomicsDto> fetchEconomics({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      CopilotApiPaths.economics,
      queryParameters: _queryParams(query),
    );
    return AiEconomicsDto.fromJson(parseCopilotEnvelope(_responseMap(response)));
  }

  Future<List<CopilotSessionDto>> fetchSessions({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      CopilotApiPaths.sessions,
      queryParameters: _queryParams(query),
    );
    return parseCopilotItems(_responseMap(response))
        .map(CopilotSessionDto.fromJson)
        .toList();
  }

  Future<CopilotSessionDto> createSession({
    required RepositoryQuery query,
    required CopilotAssistantType assistantType,
    String? title,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      CopilotApiPaths.sessions,
      queryParameters: _queryParams(query),
      data: {
        'assistantType': assistantType.name,
        if (title != null) 'title': title,
      },
    );
    return CopilotSessionDto.fromJson(parseCopilotEnvelope(_responseMap(response)));
  }

  Future<CopilotSessionDetailDto> fetchSession({
    required RepositoryQuery query,
    required String sessionId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      CopilotApiPaths.session(sessionId),
      queryParameters: _queryParams(query),
    );
    return CopilotSessionDetailDto.fromJson(parseCopilotEnvelope(_responseMap(response)));
  }

  Future<CopilotSendMessageResultDto> sendMessage({
    required RepositoryQuery query,
    required String sessionId,
    required String content,
    CopilotScreenContext? screenContext,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      CopilotApiPaths.messages(sessionId),
      queryParameters: _queryParams(query),
      data: {
        'content': content,
        if (screenContext != null) 'screenContext': screenContext.toJson(),
      },
    );
    return CopilotSendMessageResultDto.fromJson(parseCopilotEnvelope(_responseMap(response)));
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
