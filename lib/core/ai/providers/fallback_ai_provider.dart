import '../ai_inference_models.dart';
import '../ai_provider.dart';

/// Wraps primary provider with deterministic fallback (FV-PLAT-10).
class FallbackAiProvider implements AiProvider {
  FallbackAiProvider({
    required AiProvider primary,
    required AiProvider fallback,
  })  : _primary = primary,
        _fallback = fallback;

  final AiProvider _primary;
  final AiProvider _fallback;

  @override
  String get id => '${_primary.id}+${_fallback.id}';

  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    try {
      final response = await _primary.complete(request);
      if (response.content.trim().isEmpty) {
        return _withFallback(await _fallback.complete(request));
      }
      return response;
    } catch (_) {
      return _withFallback(await _fallback.complete(request));
    }
  }

  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {
    try {
      var emitted = false;
      await for (final chunk in _primary.stream(request)) {
        emitted = true;
        yield chunk;
      }
      if (!emitted) {
        yield* _fallback.stream(request);
      }
    } catch (_) {
      yield* _fallback.stream(request);
    }
  }

  AiInferenceResponse _withFallback(AiInferenceResponse response) {
    return AiInferenceResponse(
      content: response.content,
      provider: response.provider,
      fromCache: response.fromCache,
      usedFallback: true,
      model: response.model,
      latencyMs: response.latencyMs,
      metadata: {...response.metadata, 'fallback': true},
    );
  }
}
