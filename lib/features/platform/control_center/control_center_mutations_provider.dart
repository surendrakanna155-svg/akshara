import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'control_center_models.dart';
import 'control_center_providers.dart';
import 'control_center_requests.dart';

void assertManageControlCenter(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null || !perms.has(Permission.manageControlCenter)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage the control center.',
        code: 'RBAC_MANAGE_CONTROL_CENTER',
      ),
    );
  }
}

class CreateSchoolNotifier extends AsyncNotifier<PlatformSchool?> {
  @override
  FutureOr<PlatformSchool?> build() => null;

  Future<PlatformSchool?> execute(CreateSchoolRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageControlCenter(ref);
      try {
        final result = await ref.read(controlCenterRepositoryProvider).createSchool(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(controlCenterSchoolsFutureProvider)
          ..invalidate(controlCenterDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createSchoolProvider =
    AsyncNotifierProvider<CreateSchoolNotifier, PlatformSchool?>(
  CreateSchoolNotifier.new,
);

class CreateCrmLeadNotifier extends AsyncNotifier<CrmDeal?> {
  @override
  FutureOr<CrmDeal?> build() => null;

  Future<CrmDeal?> execute(CreateCrmLeadRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageControlCenter(ref);
      try {
        final result = await ref.read(controlCenterRepositoryProvider).createLead(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(controlCenterCrmFutureProvider)
          ..invalidate(controlCenterDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createCrmLeadProvider =
    AsyncNotifierProvider<CreateCrmLeadNotifier, CrmDeal?>(
  CreateCrmLeadNotifier.new,
);
