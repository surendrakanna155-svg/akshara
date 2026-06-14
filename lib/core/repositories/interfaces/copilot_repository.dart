import '../../../features/copilot/copilot_models.dart';
import '../../../features/copilot/copilot_screen_context.dart';
import '../repository_query.dart';

abstract class CopilotRepository {
  Future<List<CopilotAssistant>> getAssistants({required RepositoryQuery query});

  Future<CopilotSuggestions> getSuggestions({
    required RepositoryQuery query,
    required CopilotAssistantType assistantType,
  });

  Future<List<CopilotSession>> getSessions({required RepositoryQuery query});

  Future<CopilotSession> createSession({
    required RepositoryQuery query,
    required CopilotAssistantType assistantType,
    String? title,
  });

  Future<CopilotSessionDetail> getSession({
    required RepositoryQuery query,
    required String sessionId,
  });

  Future<CopilotSendMessageResult> sendMessage({
    required RepositoryQuery query,
    required String sessionId,
    required String content,
    CopilotScreenContext? screenContext,
  });
}
