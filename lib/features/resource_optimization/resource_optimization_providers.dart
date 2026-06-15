import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_inference_providers.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/tenant/tenant_provider.dart';
import 'resource_optimization_models.dart';
import 'resource_optimization_repository.dart';

final resourceOptimizationRepositoryProvider =
    Provider<ResourceOptimizationRepository>((ref) {
  return MockResourceOptimizationRepository(
    pipeline: ref.watch(aiInferencePipelineProvider),
  );
});

final resourceOptimizationQueryProvider = Provider<RepositoryQuery>((ref) {
  return ref.watch(repositoryQueryProvider);
});

final resourceOptimizationRecommendationsProvider = FutureProvider.family<
    List<OptimizationRecommendation>,
    ResourceOptimizationDomain>((ref, domain) async {
  return ref.read(resourceOptimizationRepositoryProvider).listRecommendations(
        query: ref.watch(resourceOptimizationQueryProvider),
        domain: domain,
      );
});
