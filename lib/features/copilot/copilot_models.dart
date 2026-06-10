import 'package:flutter/foundation.dart';

enum CopilotAssistantType {
  admissions,
  finance,
  sis,
  academic,
  communication;

  String get label => switch (this) {
        CopilotAssistantType.admissions => 'Admissions Assistant',
        CopilotAssistantType.finance => 'Finance Assistant',
        CopilotAssistantType.sis => 'SIS Assistant',
        CopilotAssistantType.academic => 'Academic Assistant',
        CopilotAssistantType.communication => 'Communication Assistant',
      };

  static CopilotAssistantType? fromApi(String value) {
    for (final type in CopilotAssistantType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

@immutable
class CopilotAssistant {
  const CopilotAssistant({
    required this.type,
    required this.label,
    required this.description,
    required this.skills,
  });

  final CopilotAssistantType type;
  final String label;
  final String description;
  final List<String> skills;
}

@immutable
class CopilotSession {
  const CopilotSession({
    required this.id,
    required this.assistantType,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final CopilotAssistantType assistantType;
  final String title;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

@immutable
class CopilotMessage {
  const CopilotMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.metadata = const {},
  });

  final String id;
  final String sessionId;
  final String role;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}

@immutable
class CopilotSessionDetail {
  const CopilotSessionDetail({
    required this.session,
    required this.messages,
  });

  final CopilotSession session;
  final List<CopilotMessage> messages;
}

@immutable
class CopilotSendMessageResult {
  const CopilotSendMessageResult({
    required this.userMessage,
    required this.assistantMessage,
    required this.model,
    required this.stub,
  });

  final CopilotMessage userMessage;
  final CopilotMessage assistantMessage;
  final String model;
  final bool stub;
}

@immutable
class CopilotSuggestions {
  const CopilotSuggestions({
    required this.assistantType,
    required this.prompts,
  });

  final CopilotAssistantType assistantType;
  final List<String> prompts;
}
