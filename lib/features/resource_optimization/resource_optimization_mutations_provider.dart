import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import 'resource_optimization_models.dart';
import 'resource_optimization_providers.dart';

void assertManageResourceOptimization(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null || !permissions.has(Permission.manageManagement)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to apply optimization actions.',
        code: 'RBAC_MANAGE_RESOURCE_OPTIMIZATION',
      ),
    );
  }
}

class ApplyResourceOptimizationRecommendationNotifier
    extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute({
    required ResourceOptimizationDomain domain,
    required String recommendationId,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageResourceOptimization(ref);
      await ref
          .read(resourceOptimizationRepositoryProvider)
          .applyRecommendation(
            query: ref.read(resourceOptimizationQueryProvider),
            domain: domain,
            recommendationId: recommendationId,
          );
      ref.invalidate(resourceOptimizationRecommendationsProvider(domain));
      return recommendationId;
    });
    return state.valueOrNull;
  }
}

final applyResourceOptimizationRecommendationProvider = AsyncNotifierProvider<
    ApplyResourceOptimizationRecommendationNotifier, String?>(
  ApplyResourceOptimizationRecommendationNotifier.new,
);

class DismissResourceOptimizationRecommendationNotifier
    extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute({
    required ResourceOptimizationDomain domain,
    required String recommendationId,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageResourceOptimization(ref);
      await ref
          .read(resourceOptimizationRepositoryProvider)
          .dismissRecommendation(
            query: ref.read(resourceOptimizationQueryProvider),
            domain: domain,
            recommendationId: recommendationId,
          );
      ref.invalidate(resourceOptimizationRecommendationsProvider(domain));
      return recommendationId;
    });
    return state.valueOrNull;
  }
}

final dismissResourceOptimizationRecommendationProvider = AsyncNotifierProvider<
    DismissResourceOptimizationRecommendationNotifier, String?>(
  DismissResourceOptimizationRecommendationNotifier.new,
);
