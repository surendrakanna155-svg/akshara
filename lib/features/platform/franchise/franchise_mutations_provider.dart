import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../platform_backend_guard.dart';
import 'franchise_models.dart';
import 'franchise_providers.dart';

void assertManageFranchiseOperations(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null ||
      !permissions.has(Permission.manageFranchiseOperations)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage franchise operations.',
        code: 'RBAC_MANAGE_FRANCHISE_OPERATIONS',
      ),
    );
  }
}

class FranchiseMutationsNotifier extends AsyncNotifier<FranchiseEntity?> {
  @override
  FutureOr<FranchiseEntity?> build() => null;

  Future<FranchiseEntity?> improveScore({
    required String franchiseId,
    int delta = 1,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageFranchiseOperations(ref);
      assertFranchiseBackendAvailable(ref);
      final entity =
          await ref.read(franchiseRepositoryProvider).updateFranchiseScore(
                query: ref.read(repositoryQueryProvider),
                franchiseId: franchiseId,
                delta: delta,
              );
      ref.invalidate(franchiseDashboardProvider);
      return entity;
    });
    return state.valueOrNull;
  }
}

final franchiseMutationsProvider =
    AsyncNotifierProvider<FranchiseMutationsNotifier, FranchiseEntity?>(
  FranchiseMutationsNotifier.new,
);
