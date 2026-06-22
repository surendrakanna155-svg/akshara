import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/copilot/content/ai_content_models.dart';
import 'package:akshara_erp/features/copilot/content/ai_content_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAiProvider implements AiProvider {
  @override
  String get id => 'fake-ai';

  AiInferenceRequest? lastRequest;

  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    lastRequest = request;
    return const AiInferenceResponse(
      content: 'Dear Parents, tomorrow is a holiday.',
      provider: 'fake-ai',
      fromCache: false,
      usedFallback: false,
    );
  }

  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {}
}

void main() {
  test('generate uses contentGeneration task type', () async {
    final provider = _FakeAiProvider();
    final pipeline = AiInferencePipeline(
      provider: provider,
      cache: AiResponseCache(),
      telemetry: AiInferenceTelemetry(),
      rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
    );
    final service = AiContentService(pipeline: pipeline);

    final result = await service.generate(
      const AiContentRequest(
        type: AiContentType.notice,
        prompt: 'Holiday tomorrow',
        audience: 'Parents',
        tone: 'Formal',
      ),
    );

    expect(result.content, contains('holiday'));
    expect(provider.lastRequest?.taskType, 'contentGeneration');
    expect(provider.lastRequest?.context['type'], 'notice');
  });
}
