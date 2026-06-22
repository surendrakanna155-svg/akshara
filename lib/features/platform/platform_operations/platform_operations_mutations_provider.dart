import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'platform_operations_models.dart';
import 'platform_operations_providers.dart';

void assertManagePlatformOperations(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null ||
      !permissions.has(Permission.managePlatformOperations)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message:
            'You do not have permission to manage platform operations.',
        code: 'RBAC_MANAGE_PLATFORM_OPERATIONS',
      ),
    );
  }
}

void _invalidatePlatformOperationsReads(Ref ref) {
  ref.invalidate(activeAlertsProvider);
  ref.invalidate(alertHistoryProvider);
  ref.invalidate(tenantIsolationDashboardProvider);
  ref.invalidate(accessReviewsProvider);
  ref.invalidate(securityDashboardProvider);
}

class AcknowledgeAlertNotifier extends AsyncNotifier<PlatformAlert?> {
  @override
  FutureOr<PlatformAlert?> build() => null;

  Future<PlatformAlert?> execute({
    required String alertId,
    String? note,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManagePlatformOperations(ref);
      try {
        final result = await ref
            .read(platformOperationsRepositoryProvider)
            .acknowledgeAlert(
              query: ref.read(repositoryQueryProvider),
              alertId: alertId,
              note: note,
            );
        _invalidatePlatformOperationsReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final acknowledgeAlertProvider =
    AsyncNotifierProvider<AcknowledgeAlertNotifier, PlatformAlert?>(
  AcknowledgeAlertNotifier.new,
);

class RunTenantVerificationNotifier
    extends AsyncNotifier<TenantVerificationReport?> {
  @override
  FutureOr<TenantVerificationReport?> build() => null;

  Future<TenantVerificationReport?> execute() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManagePlatformOperations(ref);
      try {
        final result = await ref
            .read(platformOperationsRepositoryProvider)
            .runTenantVerification(
              query: ref.read(repositoryQueryProvider),
            );
        _invalidatePlatformOperationsReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final runTenantVerificationProvider =
    AsyncNotifierProvider<RunTenantVerificationNotifier,
        TenantVerificationReport?>(
  RunTenantVerificationNotifier.new,
);

class CompleteAccessReviewNotifier extends AsyncNotifier<AccessReviewItem?> {
  @override
  FutureOr<AccessReviewItem?> build() => null;

  Future<AccessReviewItem?> execute({required String reviewId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManagePlatformOperations(ref);
      try {
        final result = await ref
            .read(platformOperationsRepositoryProvider)
            .completeAccessReview(
              query: ref.read(repositoryQueryProvider),
              reviewId: reviewId,
            );
        _invalidatePlatformOperationsReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final completeAccessReviewProvider =
    AsyncNotifierProvider<CompleteAccessReviewNotifier, AccessReviewItem?>(
  CompleteAccessReviewNotifier.new,
);
