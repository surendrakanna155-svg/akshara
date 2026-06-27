import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'dynamic_widget_models.dart';
import 'dynamic_widget_providers.dart';

void assertManageDynamicWidgets(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null ||
      !permissions.has(Permission.manageDynamicWidgets)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage dynamic widgets.',
        code: 'RBAC_MANAGE_DYNAMIC_WIDGETS',
      ),
    );
  }
}

void _invalidateDynamicWidgetReads(Ref ref, {required String role}) {
  ref.invalidate(roleDashboardLayoutProvider(role));
  ref.invalidate(
    widgetLayoutVersionsProvider((role: role, pack: ref.read(dynamicWidgetVerticalPackProvider))),
  );
  ref.invalidate(dynamicWidgetLiveDataProvider(role));
}

class SaveRoleDashboardLayoutNotifier extends AsyncNotifier<RoleDashboardLayout?> {
  @override
  FutureOr<RoleDashboardLayout?> build() => null;

  Future<RoleDashboardLayout?> execute({
    required String role,
    required RoleDashboardLayout layout,
    int? version,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageDynamicWidgets(ref);
      try {
        final result = await ref.read(evolutionRepositoryProvider).saveRoleDashboardLayout(
              query: ref.read(repositoryQueryProvider),
              role: role,
              layout: layout,
              version: version,
            );
        _invalidateDynamicWidgetReads(ref, role: role);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final saveRoleDashboardLayoutProvider =
    AsyncNotifierProvider<SaveRoleDashboardLayoutNotifier, RoleDashboardLayout?>(
  SaveRoleDashboardLayoutNotifier.new,
);

class ResetLayoutToPackDefaultNotifier extends AsyncNotifier<RoleDashboardLayout?> {
  @override
  FutureOr<RoleDashboardLayout?> build() => null;

  Future<RoleDashboardLayout?> execute({
    required String role,
    required String verticalPack,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageDynamicWidgets(ref);
      try {
        final result =
            await ref.read(evolutionRepositoryProvider).resetLayoutToPackDefault(
                  query: ref.read(repositoryQueryProvider),
                  role: role,
                  verticalPack: verticalPack,
                );
        _invalidateDynamicWidgetReads(ref, role: role);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final resetLayoutToPackDefaultProvider =
    AsyncNotifierProvider<ResetLayoutToPackDefaultNotifier, RoleDashboardLayout?>(
  ResetLayoutToPackDefaultNotifier.new,
);
