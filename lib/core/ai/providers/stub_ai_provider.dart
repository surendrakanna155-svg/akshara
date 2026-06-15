import '../../../features/copilot/copilot_stub_responses.dart';
import '../../../features/copilot/copilot_screen_context.dart';
import '../ai_inference_models.dart';
import '../ai_provider.dart';

/// Deterministic local inference for offline/demo mode (FV-PLAT-10).
class StubAiProvider implements AiProvider {
  @override
  String get id => 'akshara-stub';

  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final screenContext = _screenContextFrom(request);
    final content = buildContextAwareStubReply(
      userMessage: request.prompt,
      screenContext: screenContext,
    );
    return AiInferenceResponse(
      content: content,
      provider: id,
      fromCache: false,
      usedFallback: true,
      model: 'akshara-stub-v1',
      latencyMs: 120,
      metadata: const {'stub': true},
    );
  }

  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {
    final response = await complete(request);
    final words = response.content.split(' ');
    for (var i = 0; i < words.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 8));
      yield AiInferenceStreamChunk(
        delta: '${words[i]} ',
        done: i == words.length - 1,
        provider: id,
      );
    }
  }

  CopilotScreenContext? _screenContextFrom(AiInferenceRequest request) {
    final ctx = request.context;
    if (ctx.isEmpty) return null;
    return CopilotScreenContext.fromJson({
      'route': ctx['route'] ?? '/',
      'screen': ctx['screen'] ?? 'ERP',
      'module': ctx['module'] ?? 'general',
      'schoolId': ctx['schoolId'] ?? '',
      'personaRole': ctx['personaRole'] ?? 'directorCorrespondent',
      'erpRole': ctx['erpRole'] ?? 'management',
      'organizationId': ctx['organizationId'] ?? '',
      'tenantId': ctx['tenantId'] ?? '',
      if (ctx['activeChildId'] != null) 'activeChildId': ctx['activeChildId'],
      'filters': ctx['filters'] ?? const {},
    });
  }
}
