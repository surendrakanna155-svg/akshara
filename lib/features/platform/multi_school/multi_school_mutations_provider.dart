import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../platform_backend_guard.dart';
import 'multi_school_models.dart';
import 'multi_school_providers.dart';

void assertManageMultiSchoolOperations(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null ||
      !permissions.has(Permission.manageMultiSchoolOperations)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message:
            'You do not have permission to manage multi-school operations.',
        code: 'RBAC_MANAGE_MULTI_SCHOOL_OPERATIONS',
      ),
    );
  }
}

void _invalidateMultiSchoolReads(Ref ref) {
  ref.invalidate(multiSchoolPortfolioDashboardProvider);
  ref.invalidate(multiSchoolSchoolsProvider);
  ref.invalidate(multiSchoolAlertsProvider);
  ref.invalidate(multiSchoolPendingActionsProvider);
}

class ActivateSchoolNotifier extends AsyncNotifier<SchoolLifecycleRecord?> {
  @override
  FutureOr<SchoolLifecycleRecord?> build() => null;

  Future<SchoolLifecycleRecord?> execute({required String schoolId}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageMultiSchoolOperations(ref);
      assertMultiSchoolBackendAvailable(ref);
      try {
        final result = await ref
            .read(multiSchoolOperationsRepositoryProvider)
            .activateSchool(
              query: ref.read(repositoryQueryProvider),
              schoolId: schoolId,
            );
        _invalidateMultiSchoolReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final activateSchoolProvider =
    AsyncNotifierProvider<ActivateSchoolNotifier, SchoolLifecycleRecord?>(
  ActivateSchoolNotifier.new,
);

class DeactivateSchoolNotifier extends AsyncNotifier<SchoolLifecycleRecord?> {
  @override
  FutureOr<SchoolLifecycleRecord?> build() => null;

  Future<SchoolLifecycleRecord?> execute({
    required String schoolId,
    String? reason,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageMultiSchoolOperations(ref);
      assertMultiSchoolBackendAvailable(ref);
      try {
        final result = await ref
            .read(multiSchoolOperationsRepositoryProvider)
            .deactivateSchool(
              query: ref.read(repositoryQueryProvider),
              schoolId: schoolId,
              reason: reason,
            );
        _invalidateMultiSchoolReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final deactivateSchoolProvider =
    AsyncNotifierProvider<DeactivateSchoolNotifier, SchoolLifecycleRecord?>(
  DeactivateSchoolNotifier.new,
);

class CompleteOnboardingNotifier extends AsyncNotifier<SchoolLifecycleRecord?> {
  @override
  FutureOr<SchoolLifecycleRecord?> build() => null;

  Future<SchoolLifecycleRecord?> execute({
    required SchoolOnboardingDraft draft,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageMultiSchoolOperations(ref);
      assertMultiSchoolBackendAvailable(ref);
      try {
        final saved = await ref
            .read(multiSchoolOperationsRepositoryProvider)
            .createOnboardingDraft(
              query: ref.read(repositoryQueryProvider),
              draft: draft,
            );
        final result = await ref
            .read(multiSchoolOperationsRepositoryProvider)
            .submitOnboarding(
              query: ref.read(repositoryQueryProvider),
              draftId: saved.id,
            );
        _invalidateMultiSchoolReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final completeOnboardingProvider =
    AsyncNotifierProvider<CompleteOnboardingNotifier, SchoolLifecycleRecord?>(
  CompleteOnboardingNotifier.new,
);

class DismissPortfolioAlertNotifier extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute({required String alertId}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageMultiSchoolOperations(ref);
      assertMultiSchoolBackendAvailable(ref);
      try {
        await ref.read(multiSchoolOperationsRepositoryProvider).dismissAlert(
              query: ref.read(repositoryQueryProvider),
              alertId: alertId,
            );
        _invalidateMultiSchoolReads(ref);
        return alertId;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final dismissPortfolioAlertProvider =
    AsyncNotifierProvider<DismissPortfolioAlertNotifier, String?>(
  DismissPortfolioAlertNotifier.new,
);

class CompletePortfolioActionNotifier extends AsyncNotifier<PortfolioAction?> {
  @override
  FutureOr<PortfolioAction?> build() => null;

  Future<PortfolioAction?> execute({required String actionId}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageMultiSchoolOperations(ref);
      assertMultiSchoolBackendAvailable(ref);
      try {
        final result = await ref
            .read(multiSchoolOperationsRepositoryProvider)
            .completeAction(
              query: ref.read(repositoryQueryProvider),
              actionId: actionId,
            );
        _invalidateMultiSchoolReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final completePortfolioActionProvider =
    AsyncNotifierProvider<CompletePortfolioActionNotifier, PortfolioAction?>(
  CompletePortfolioActionNotifier.new,
);
