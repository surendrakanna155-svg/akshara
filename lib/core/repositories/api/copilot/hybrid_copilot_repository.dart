import '../../interfaces/copilot_repository.dart';
import '../../repository_query.dart';
import '../../../../features/copilot/copilot_models.dart';
import '../../../../features/copilot/copilot_screen_context.dart';
import 'api_copilot_repository.dart';

class HybridCopilotRepository implements CopilotRepository {
  HybridCopilotRepository({required ApiCopilotRepository api}) : _api = api;

  final ApiCopilotRepository _api;

  @override
  Future<List<CopilotAssistant>> getAssistants({required RepositoryQuery query}) =>
      _api.getAssistants(query: query);

  @override
  Future<CopilotSuggestions> getSuggestions({
    required RepositoryQuery query,
    required CopilotAssistantType assistantType,
  }) =>
      _api.getSuggestions(query: query, assistantType: assistantType);

  @override
  Future<List<CopilotSession>> getSessions({required RepositoryQuery query}) =>
      _api.getSessions(query: query);

  @override
  Future<CopilotSession> createSession({
    required RepositoryQuery query,
    required CopilotAssistantType assistantType,
    String? title,
  }) =>
      _api.createSession(query: query, assistantType: assistantType, title: title);

  @override
  Future<CopilotSessionDetail> getSession({
    required RepositoryQuery query,
    required String sessionId,
  }) =>
      _api.getSession(query: query, sessionId: sessionId);

  @override
  Future<CopilotSendMessageResult> sendMessage({
    required RepositoryQuery query,
    required String sessionId,
    required String content,
    CopilotScreenContext? screenContext,
  }) =>
      _api.sendMessage(
        query: query,
        sessionId: sessionId,
        content: content,
        screenContext: screenContext,
      );
}
