import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingProvider implements AiProvider {
  int calls = 0;

  @override
  String get id => 'recording';

  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    calls++;
    return AiInferenceResponse(
      content: 'reply:${request.prompt}',
      provider: id,
      fromCache: false,
      usedFallback: false,
    );
  }

  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {
    yield const AiInferenceStreamChunk(delta: 'a', done: false);
    yield const AiInferenceStreamChunk(delta: 'b', done: true);
  }
}

void main() {
  group('AiInferencePipeline', () {
    late _RecordingProvider provider;
    late AiResponseCache cache;
    late AiInferenceTelemetry telemetry;
    late AiInferencePipeline pipeline;

    setUp(() {
      provider = _RecordingProvider();
      cache = AiResponseCache();
      telemetry = AiInferenceTelemetry();
      pipeline = AiInferencePipeline(
        provider: provider,
        cache: cache,
        telemetry: telemetry,
        rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
      );
    });

    test('caches repeated complete requests', () async {
      const request = AiInferenceRequest(
        prompt: 'hello',
        taskType: 'copilotChat',
        cacheKey: 'hello',
      );
      final first = await pipeline.complete(request);
      final second = await pipeline.complete(request);
      expect(first.fromCache, isFalse);
      expect(second.fromCache, isTrue);
      expect(provider.calls, 1);
      expect(telemetry.events.where((e) => e.fromCache).length, 1);
    });

    test('denies when RBAC missing', () async {
      final denied = AiInferencePipeline(
        provider: provider,
        cache: cache,
        telemetry: telemetry,
        rbac: RbacService(UserPermissions.forRole(ErpRole.student)),
      );
      expect(
        () => denied.complete(
          const AiInferenceRequest(prompt: 'x', taskType: 'copilotChat'),
        ),
        throwsStateError,
      );
    });

    test('streams chunks from provider', () async {
      final chunks = await pipeline
          .stream(
            const AiInferenceRequest(
              prompt: 'stream',
              taskType: 'copilotChat',
              stream: true,
            ),
          )
          .toList();
      expect(chunks.length, 2);
      expect(chunks.last.done, isTrue);
    });
  });
}
