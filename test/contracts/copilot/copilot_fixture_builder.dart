import 'package:akshara_erp/features/copilot/copilot_models.dart';

class CopilotFixtureBuilder {
  Map<String, dynamic> envelope(Map<String, dynamic> data) {
    return {
      'success': true,
      'data': data,
    };
  }

  Map<String, dynamic> assistantsEnvelope(List<CopilotAssistant> assistants) {
    return envelope({
      'items': [
        for (final assistant in assistants)
          {
            'type': assistant.type.name,
            'label': assistant.label,
            'description': assistant.description,
            'skills': assistant.skills,
          },
      ],
    });
  }

  Map<String, dynamic> suggestionsEnvelope(CopilotSuggestions suggestions) {
    return envelope({
      'assistant': suggestions.assistantType.name,
      'prompts': suggestions.prompts,
    });
  }

  Map<String, dynamic> sessionsEnvelope(List<CopilotSession> sessions) {
    return envelope({
      'items': [
        for (final session in sessions) sessionItem(session),
      ],
    });
  }

  Map<String, dynamic> sessionItem(CopilotSession session) {
    return {
      'id': session.id,
      'assistantType': session.assistantType.name,
      'title': session.title,
      'status': session.status,
      'createdAt': session.createdAt.toIso8601String(),
      'updatedAt': session.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> sessionDetailEnvelope(CopilotSessionDetail detail) {
    return envelope({
      'session': sessionItem(detail.session),
      'messages': [
        for (final message in detail.messages) messageItem(message),
      ],
    });
  }

  Map<String, dynamic> messageItem(CopilotMessage message) {
    return {
      'id': message.id,
      'sessionId': message.sessionId,
      'role': message.role,
      'content': message.content,
      'createdAt': message.createdAt.toIso8601String(),
      'metadata': message.metadata,
    };
  }

  Map<String, dynamic> sendMessageEnvelope(CopilotSendMessageResult result) {
    return envelope({
      'userMessage': messageItem(result.userMessage),
      'assistantMessage': messageItem(result.assistantMessage),
      'model': result.model,
      'stub': result.stub,
    });
  }
}
