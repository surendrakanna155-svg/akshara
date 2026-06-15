import '../security/permissions.dart';
import '../security/rbac_service.dart';
import 'ai_inference_models.dart';
import 'ai_inference_telemetry.dart';
import 'ai_provider.dart';
import 'ai_response_cache.dart';

/// Orchestrates cache, RBAC, telemetry, and provider selection (FV-PLAT-10).
class AiInferencePipeline {
  AiInferencePipeline({
    required AiProvider provider,
    required AiResponseCache cache,
    required AiInferenceTelemetry telemetry,
    required RbacService rbac,
  })  : _provider = provider,
        _cache = cache,
        _telemetry = telemetry,
        _rbac = rbac;

  final AiProvider _provider;
  final AiResponseCache _cache;
  final AiInferenceTelemetry _telemetry;
  final RbacService _rbac;

  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    _assertPermission(request.taskType);
    final cacheKey = buildAiCacheKey(request);
    if (!request.stream) {
      final cached = _cache.get(cacheKey);
      if (cached != null) {
        _telemetry.record(
          AiInferenceEvent(
            taskType: request.taskType,
            provider: cached.provider,
            success: true,
            fromCache: true,
            usedFallback: cached.usedFallback,
            latencyMs: 0,
          ),
        );
        return AiInferenceResponse(
          content: cached.content,
          provider: cached.provider,
          fromCache: true,
          usedFallback: cached.usedFallback,
          model: cached.model,
          latencyMs: 0,
          metadata: cached.metadata,
        );
      }
    }

    final started = DateTime.now();
    try {
      final response = await _provider.complete(request);
      if (!request.stream && response.content.isNotEmpty) {
        _cache.put(cacheKey, response);
      }
      _telemetry.record(
        AiInferenceEvent(
          taskType: request.taskType,
          provider: response.provider,
          success: true,
          fromCache: false,
          usedFallback: response.usedFallback,
          latencyMs: response.latencyMs ??
              DateTime.now().difference(started).inMilliseconds,
        ),
      );
      return response;
    } catch (error) {
      _telemetry.record(
        AiInferenceEvent(
          taskType: request.taskType,
          provider: _provider.id,
          success: false,
          fromCache: false,
          usedFallback: false,
          latencyMs: DateTime.now().difference(started).inMilliseconds,
          errorCode: error.runtimeType.toString(),
        ),
      );
      rethrow;
    }
  }

  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {
    _assertPermission(request.taskType);
    final started = DateTime.now();
    var success = true;
    try {
      yield* _provider.stream(request);
    } catch (_) {
      success = false;
      rethrow;
    } finally {
      _telemetry.record(
        AiInferenceEvent(
          taskType: request.taskType,
          provider: _provider.id,
          success: success,
          fromCache: false,
          usedFallback: false,
          latencyMs: DateTime.now().difference(started).inMilliseconds,
        ),
      );
    }
  }

  void _assertPermission(String taskType) {
    if (!_rbac.hasPermission(Permission.viewAiCopilot)) {
      throw StateError('RBAC_AI_VIEW_DENIED');
    }
    if (!_rbac.hasPermission(Permission.runAiCopilot)) {
      throw StateError('RBAC_AI_RUN_DENIED');
    }
  }
}

String aiTaskTypeName(AiInferenceTaskType type) => switch (type) {
      AiInferenceTaskType.copilotChat => 'copilotChat',
      AiInferenceTaskType.parentMeetingSummary => 'parentMeetingSummary',
      AiInferenceTaskType.contentGeneration => 'contentGeneration',
      AiInferenceTaskType.resourceOptimization => 'resourceOptimization',
      AiInferenceTaskType.intelligenceCompute => 'intelligenceCompute',
    };
