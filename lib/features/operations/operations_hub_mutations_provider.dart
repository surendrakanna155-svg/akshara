import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../phase5/phase5_providers.dart';

void assertManageOperationsHub(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  final canManage = permissions?.has(Permission.manageManagement) == true &&
      permissions?.has(Permission.viewOperationsHub) == true;
  if (!canManage) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage Operations Hub actions.',
        code: 'RBAC_MANAGE_OPERATIONS_HUB',
      ),
    );
  }
}

class DismissOperationsAlertNotifier extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute(String alertId) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageOperationsHub(ref);
      try {
        await ref.read(operationsHubRepositoryProvider).dismissAlert(
              query: ref.read(repositoryQueryProvider),
              alertId: alertId,
            );
        ref.invalidate(operationsHubProvider);
        return alertId;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final dismissOperationsAlertProvider =
    AsyncNotifierProvider<DismissOperationsAlertNotifier, String?>(
  DismissOperationsAlertNotifier.new,
);

class CompleteOperationsActionNotifier extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute(String actionId) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageOperationsHub(ref);
      try {
        await ref.read(operationsHubRepositoryProvider).completeAction(
              query: ref.read(repositoryQueryProvider),
              actionId: actionId,
            );
        ref.invalidate(operationsHubProvider);
        return actionId;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final completeOperationsActionProvider =
    AsyncNotifierProvider<CompleteOperationsActionNotifier, String?>(
  CompleteOperationsActionNotifier.new,
);
