import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../platform_backend_guard.dart';
import 'branch_models.dart';
import 'branch_providers.dart';

void assertManageBranchOperations(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null ||
      !permissions.has(Permission.manageBranchOperations)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage branch operations.',
        code: 'RBAC_MANAGE_BRANCH_OPERATIONS',
      ),
    );
  }
}

class BranchMutationsNotifier extends AsyncNotifier<BranchAssignment?> {
  @override
  FutureOr<BranchAssignment?> build() => null;

  Future<BranchAssignment?> assignSchool({
    required String schoolId,
    required String schoolName,
    required String managerName,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageBranchOperations(ref);
      assertBranchBackendAvailable(ref);
      final assignment = await ref.read(branchRepositoryProvider).assignSchool(
            query: ref.read(repositoryQueryProvider),
            branchId: ref.read(selectedBranchIdProvider),
            schoolId: schoolId,
            schoolName: schoolName,
            managerName: managerName,
          );
      ref.invalidate(branchAssignmentsProvider);
      return assignment;
    });
    return state.valueOrNull;
  }
}

final branchMutationsProvider =
    AsyncNotifierProvider<BranchMutationsNotifier, BranchAssignment?>(
  BranchMutationsNotifier.new,
);
