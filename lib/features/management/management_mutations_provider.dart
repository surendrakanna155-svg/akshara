import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'management_models.dart';
import 'management_providers.dart';
import 'management_requests.dart';

void assertManageManagement(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null || !perms.has(Permission.manageManagement)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage executive approvals.',
        code: 'RBAC_MANAGE_MANAGEMENT',
      ),
    );
  }
}

class ResolveManagementApprovalNotifier
    extends AsyncNotifier<ManagementApprovalItem?> {
  @override
  FutureOr<ManagementApprovalItem?> build() => null;

  Future<ManagementApprovalItem?> execute(
    ResolveManagementApprovalRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageManagement(ref);
      try {
        final result =
            await ref.read(managementRepositoryProvider).resolveManagementApproval(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        ref
          ..invalidate(managementTasksFutureProvider)
          ..invalidate(managementDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final resolveManagementApprovalProvider =
    AsyncNotifierProvider<ResolveManagementApprovalNotifier,
        ManagementApprovalItem?>(
  ResolveManagementApprovalNotifier.new,
);
