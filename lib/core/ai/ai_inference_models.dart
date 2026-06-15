/// Live AI inference request/response models (FV-PLAT-10).
class AiInferenceRequest {
  const AiInferenceRequest({
    required this.prompt,
    required this.taskType,
    this.systemPrompt,
    this.context = const {},
    this.stream = false,
    this.cacheKey,
    this.maxTokens = 1024,
  });

  final String prompt;
  final String taskType;
  final String? systemPrompt;
  final Map<String, Object?> context;
  final bool stream;
  final String? cacheKey;
  final int maxTokens;
}

class AiInferenceResponse {
  const AiInferenceResponse({
    required this.content,
    required this.provider,
    required this.fromCache,
    required this.usedFallback,
    this.model,
    this.latencyMs,
    this.metadata = const {},
  });

  final String content;
  final String provider;
  final bool fromCache;
  final bool usedFallback;
  final String? model;
  final int? latencyMs;
  final Map<String, Object?> metadata;
}

class AiInferenceStreamChunk {
  const AiInferenceStreamChunk({
    required this.delta,
    required this.done,
    this.provider,
  });

  final String delta;
  final bool done;
  final String? provider;
}

enum AiInferenceTaskType {
  copilotChat,
  parentMeetingSummary,
  contentGeneration,
  resourceOptimization,
  intelligenceCompute,
}
