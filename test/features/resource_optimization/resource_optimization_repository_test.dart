import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/resource_optimization/resource_optimization_models.dart';
import 'package:akshara_erp/features/resource_optimization/resource_optimization_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAiProvider implements AiProvider {
  @override
  String get id => 'fake-ai';

  AiInferenceRequest? lastRequest;

  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    lastRequest = request;
    return const AiInferenceResponse(
      content:
          'rec_alpha|Rebalance support teachers|Move one support slot|Cut wait time by 15%|91',
      provider: 'fake-ai',
      fromCache: false,
      usedFallback: false,
    );
  }

  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {}
}

void main() {
  test('listRecommendations uses resourceOptimization task type', () async {
    final provider = _FakeAiProvider();
    final pipeline = AiInferencePipeline(
      provider: provider,
      cache: AiResponseCache(),
      telemetry: AiInferenceTelemetry(),
      rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
    );
    final repo = MockResourceOptimizationRepository(pipeline: pipeline);

    final recommendations = await repo.listRecommendations(
      query: RepositoryQuery.demo,
      domain: ResourceOptimizationDomain.staffing,
    );

    expect(recommendations, isNotEmpty);
    expect(recommendations.first.id, 'rec_alpha');
    expect(provider.lastRequest?.taskType, 'resourceOptimization');
  });

  test('apply and dismiss mutate recommendation status', () async {
    final provider = _FakeAiProvider();
    final pipeline = AiInferencePipeline(
      provider: provider,
      cache: AiResponseCache(),
      telemetry: AiInferenceTelemetry(),
      rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
    );
    final repo = MockResourceOptimizationRepository(pipeline: pipeline);

    await repo.applyRecommendation(
      query: RepositoryQuery.demo,
      domain: ResourceOptimizationDomain.staffing,
      recommendationId: 'rec_alpha',
    );
    var list = await repo.listRecommendations(
      query: RepositoryQuery.demo,
      domain: ResourceOptimizationDomain.staffing,
    );
    expect(list.first.applied, isTrue);

    await repo.dismissRecommendation(
      query: RepositoryQuery.demo,
      domain: ResourceOptimizationDomain.staffing,
      recommendationId: 'rec_alpha',
    );
    list = await repo.listRecommendations(
      query: RepositoryQuery.demo,
      domain: ResourceOptimizationDomain.staffing,
    );
    expect(list.first.dismissed, isTrue);
    expect(list.first.applied, isFalse);
  });
}
