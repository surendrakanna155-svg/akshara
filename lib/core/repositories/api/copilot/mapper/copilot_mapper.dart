import '../../../../../features/copilot/copilot_models.dart';
import '../dto/copilot_dto.dart';

class CopilotMapper {
  const CopilotMapper();

  CopilotAssistant toAssistant(CopilotAssistantDto dto) {
    return CopilotAssistant(
      type: CopilotAssistantType.fromApi(dto.type) ?? CopilotAssistantType.finance,
      label: dto.label,
      description: dto.description,
      skills: dto.skills,
    );
  }

  List<CopilotAssistant> toAssistants(List<CopilotAssistantDto> items) {
    return items.map(toAssistant).toList();
  }

  CopilotSession toSession(CopilotSessionDto dto) {
    return CopilotSession(
      id: dto.id,
      assistantType:
          CopilotAssistantType.fromApi(dto.assistantType) ?? CopilotAssistantType.finance,
      title: dto.title,
      status: dto.status,
      createdAt: DateTime.parse(dto.createdAt),
      updatedAt: DateTime.parse(dto.updatedAt),
    );
  }

  CopilotMessage toMessage(CopilotMessageDto dto) {
    return CopilotMessage(
      id: dto.id,
      sessionId: dto.sessionId,
      role: dto.role,
      content: dto.content,
      createdAt: DateTime.parse(dto.createdAt),
      metadata: dto.metadata,
    );
  }

  CopilotSessionDetail toSessionDetail(CopilotSessionDetailDto dto) {
    return CopilotSessionDetail(
      session: toSession(dto.session),
      messages: dto.messages.map(toMessage).toList(),
    );
  }

  CopilotSuggestions toSuggestions(CopilotSuggestionsDto dto) {
    return CopilotSuggestions(
      assistantType:
          CopilotAssistantType.fromApi(dto.assistant) ?? CopilotAssistantType.finance,
      prompts: dto.prompts,
    );
  }

  CopilotSendMessageResult toSendResult(CopilotSendMessageResultDto dto) {
    return CopilotSendMessageResult(
      userMessage: toMessage(dto.userMessage),
      assistantMessage: toMessage(dto.assistantMessage),
      model: dto.model,
      stub: dto.stub,
    );
  }

  AiEconomics toEconomics(AiEconomicsDto dto) {
    return AiEconomics(
      monthStart: dto.monthStart,
      spendMicros: dto.spendMicros,
      spendCapMicros: dto.spendCapMicros,
      spendWarnRatio: dto.spendWarnRatio,
      atSpendWarn: dto.atSpendWarn,
      atSpendCap: dto.atSpendCap,
      modelCalls: dto.modelCalls,
      fallbacks: dto.fallbacks,
      callsByOutcome: dto.callsByOutcome,
      callsBySurface: dto.callsBySurface,
      cacheEntries: dto.cacheEntries,
      cacheHits: dto.cacheHits,
      tokensSaved: dto.tokensSaved,
      cacheHitRatio: dto.cacheHitRatio,
    );
  }
}
