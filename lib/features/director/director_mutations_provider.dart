import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'director_models.dart';
import 'director_providers.dart';

void assertManageDirectorPortal(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  final canManage =
      permissions != null && permissions.has(Permission.manageDirectorPortal);
  if (!canManage) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message:
            'You do not have permission to manage director portal actions.',
        code: 'RBAC_MANAGE_DIRECTOR_PORTAL',
      ),
    );
  }
}

class DirectorMutationsNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<DirectorComplianceItem> acknowledgeCompliance({
    required String complianceId,
  }) async {
    state = const AsyncLoading();
    try {
      assertManageDirectorPortal(ref);
      final updated =
          await ref.read(directorRepositoryProvider).acknowledgeCompliance(
                query: ref.read(repositoryQueryProvider),
                complianceId: complianceId,
              );
      ref.invalidate(directorComplianceProvider);
      state = const AsyncData(null);
      return updated;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<String> exportReport({required String reportId}) async {
    state = const AsyncLoading();
    try {
      assertManageDirectorPortal(ref);
      final exportId = await ref.read(directorRepositoryProvider).exportReport(
            query: ref.read(repositoryQueryProvider),
            reportId: reportId,
          );
      state = const AsyncData(null);
      return exportId;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final directorMutationsProvider =
    AsyncNotifierProvider<DirectorMutationsNotifier, void>(
  DirectorMutationsNotifier.new,
);
