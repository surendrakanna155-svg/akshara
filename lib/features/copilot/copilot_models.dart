import 'package:flutter/foundation.dart';

enum CopilotAssistantType {
  admissions,
  finance,
  sis,
  academic,
  communication,
  parentGuidance,
  teacher,
  principal;

  String get label => switch (this) {
        CopilotAssistantType.admissions => 'Admissions Assistant',
        CopilotAssistantType.finance => 'Finance Assistant',
        CopilotAssistantType.sis => 'SIS Assistant',
        CopilotAssistantType.academic => 'Academic Assistant',
        CopilotAssistantType.communication => 'Communication Assistant',
        CopilotAssistantType.parentGuidance => 'Parent Guidance Assistant',
        CopilotAssistantType.teacher => 'Teacher Copilot',
        CopilotAssistantType.principal => 'Principal Copilot',
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

/// The N10 AI cost panel: this school's month-to-date AI spend vs cap, calls
/// by outcome/surface, and cache reuse savings (backend GET /copilot/economics,
/// RBAC viewAiCopilot). Money fields are micro-USD ints; ratios are 0..1.
@immutable
class AiEconomics {
  const AiEconomics({
    required this.monthStart,
    required this.spendMicros,
    required this.spendCapMicros,
    required this.spendWarnRatio,
    required this.atSpendWarn,
    required this.atSpendCap,
    required this.modelCalls,
    required this.fallbacks,
    required this.callsByOutcome,
    required this.callsBySurface,
    required this.cacheEntries,
    required this.cacheHits,
    required this.tokensSaved,
    required this.cacheHitRatio,
  });

  /// Degraded/zero state — used when the panel has no data yet or the
  /// Hybrid repository fails soft on a backend blip.
  const AiEconomics.empty()
      : monthStart = '',
        spendMicros = 0,
        spendCapMicros = 0,
        spendWarnRatio = 0.8,
        atSpendWarn = false,
        atSpendCap = false,
        modelCalls = 0,
        fallbacks = 0,
        callsByOutcome = const {},
        callsBySurface = const {},
        cacheEntries = 0,
        cacheHits = 0,
        tokensSaved = 0,
        cacheHitRatio = 0;

  final String monthStart;
  final int spendMicros;
  final int spendCapMicros;
  final double spendWarnRatio;

  /// True when a cap is set and month-to-date spend has reached [spendWarnRatio].
  final bool atSpendWarn;

  /// True when a cap is set and month-to-date spend has reached the cap.
  final bool atSpendCap;
  final int modelCalls;
  final int fallbacks;
  final Map<String, int> callsByOutcome;
  final Map<String, int> callsBySurface;
  final int cacheEntries;
  final int cacheHits;
  final int tokensSaved;
  final double cacheHitRatio;

  /// Spend as a fraction of the cap (0 when uncapped); UI clamps for display.
  double get spendRatio => spendCapMicros > 0 ? spendMicros / spendCapMicros : 0;
}
