import '../../admissions/dto/api_envelope_dto.dart';

Map<String, dynamic> parseCopilotEnvelope(Map<String, dynamic> json) {
  return ApiEnvelopeDto.fromJson(json).data ?? const {};
}

List<Map<String, dynamic>> parseCopilotItems(Map<String, dynamic> json) {
  final data = parseCopilotEnvelope(json);
  final items = data['items'] as List<dynamic>? ?? const [];
  return items.map((item) => item as Map<String, dynamic>).toList();
}

class CopilotAssistantDto {
  CopilotAssistantDto({
    required this.type,
    required this.label,
    required this.description,
    required this.skills,
  });

  factory CopilotAssistantDto.fromJson(Map<String, dynamic> json) {
    return CopilotAssistantDto(
      type: json['type'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      skills: (json['skills'] as List<dynamic>? ?? const [])
          .map((skill) => skill as String)
          .toList(),
    );
  }

  final String type;
  final String label;
  final String description;
  final List<String> skills;
}

class CopilotSessionDto {
  CopilotSessionDto({
    required this.id,
    required this.assistantType,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CopilotSessionDto.fromJson(Map<String, dynamic> json) {
    return CopilotSessionDto(
      id: json['id'] as String? ?? '',
      assistantType: json['assistantType'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  final String id;
  final String assistantType;
  final String title;
  final String status;
  final String createdAt;
  final String updatedAt;
}

class CopilotMessageDto {
  CopilotMessageDto({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.metadata,
  });

  factory CopilotMessageDto.fromJson(Map<String, dynamic> json) {
    return CopilotMessageDto(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      role: json['role'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final String id;
  final String sessionId;
  final String role;
  final String content;
  final String createdAt;
  final Map<String, dynamic> metadata;
}

class CopilotSuggestionsDto {
  CopilotSuggestionsDto({
    required this.assistant,
    required this.prompts,
  });

  factory CopilotSuggestionsDto.fromJson(Map<String, dynamic> json) {
    return CopilotSuggestionsDto(
      assistant: json['assistant'] as String? ?? '',
      prompts: (json['prompts'] as List<dynamic>? ?? const [])
          .map((prompt) => prompt as String)
          .toList(),
    );
  }

  final String assistant;
  final List<String> prompts;
}

class CopilotSendMessageResultDto {
  CopilotSendMessageResultDto({
    required this.userMessage,
    required this.assistantMessage,
    required this.model,
    required this.stub,
  });

  factory CopilotSendMessageResultDto.fromJson(Map<String, dynamic> json) {
    return CopilotSendMessageResultDto(
      userMessage: CopilotMessageDto.fromJson(
        json['userMessage'] as Map<String, dynamic>? ?? const {},
      ),
      assistantMessage: CopilotMessageDto.fromJson(
        json['assistantMessage'] as Map<String, dynamic>? ?? const {},
      ),
      model: json['model'] as String? ?? '',
      stub: json['stub'] as bool? ?? true,
    );
  }

  final CopilotMessageDto userMessage;
  final CopilotMessageDto assistantMessage;
  final String model;
  final bool stub;
}

class CopilotSessionDetailDto {
  CopilotSessionDetailDto({
    required this.session,
    required this.messages,
  });

  factory CopilotSessionDetailDto.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? const [];
    return CopilotSessionDetailDto(
      session: CopilotSessionDto.fromJson(
        json['session'] as Map<String, dynamic>? ?? const {},
      ),
      messages: rawMessages
          .map((m) => CopilotMessageDto.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  final CopilotSessionDto session;
  final List<CopilotMessageDto> messages;
}
