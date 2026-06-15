import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../phase4/phase4_providers.dart';
import '../phase5/phase5_providers.dart';
import 'inventory_distribution_models.dart';

void assertManageInventoryDistribution(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null ||
      (!perms.has(Permission.manageInventoryDistribution) &&
          !perms.has(Permission.manageInventory))) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage inventory distribution.',
        code: 'RBAC_MANAGE_INVENTORY_DISTRIBUTION',
      ),
    );
  }
}

void _invalidateDistributionReads(Ref ref) {
  ref.invalidate(inventoryDistributionsListProvider);
  ref.invalidate(inventoryDistributionDashboardProvider);
  ref.invalidate(distributionReportsProvider);
  ref.invalidate(inventoryReplacementRequestsProvider);
}

class CreateDistributionNotifier
    extends AsyncNotifier<InvStudentDistribution?> {
  @override
  FutureOr<InvStudentDistribution?> build() => null;

  Future<InvStudentDistribution?> execute({
    required String studentId,
    required String catalogItemId,
    required int quantity,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventoryDistribution(ref);
      try {
        final result = await ref
            .read(inventoryDistributionRepositoryProvider)
            .createDistribution(
              query: ref.read(phase4QueryProvider),
              studentId: studentId,
              catalogItemId: catalogItemId,
              quantity: quantity,
            );
        _invalidateDistributionReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createDistributionProvider =
    AsyncNotifierProvider<CreateDistributionNotifier, InvStudentDistribution?>(
  CreateDistributionNotifier.new,
);

class MarkDistributedNotifier extends AsyncNotifier<InvStudentDistribution?> {
  @override
  FutureOr<InvStudentDistribution?> build() => null;

  Future<InvStudentDistribution?> execute({
    required String distributionId,
    String? notes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventoryDistribution(ref);
      try {
        final result = await ref
            .read(inventoryDistributionRepositoryProvider)
            .transitionStatus(
              query: ref.read(phase4QueryProvider),
              distributionId: distributionId,
              status: 'distributed',
              notes: notes,
            );
        _invalidateDistributionReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final markDistributedProvider =
    AsyncNotifierProvider<MarkDistributedNotifier, InvStudentDistribution?>(
  MarkDistributedNotifier.new,
);

class RequestReplacementNotifier
    extends AsyncNotifier<InvStudentDistribution?> {
  @override
  FutureOr<InvStudentDistribution?> build() => null;

  Future<InvStudentDistribution?> execute({
    required String distributionId,
    String? notes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventoryDistribution(ref);
      try {
        final result = await ref
            .read(inventoryDistributionRepositoryProvider)
            .requestReplacement(
              query: ref.read(phase4QueryProvider),
              distributionId: distributionId,
              notes: notes,
            );
        _invalidateDistributionReads(ref);
        return result.distribution;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final requestReplacementProvider =
    AsyncNotifierProvider<RequestReplacementNotifier, InvStudentDistribution?>(
  RequestReplacementNotifier.new,
);

class ApproveReplacementNotifier extends AsyncNotifier<InvReplacementRequest?> {
  @override
  FutureOr<InvReplacementRequest?> build() => null;

  Future<InvReplacementRequest?> execute({required String requestId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventoryDistribution(ref);
      try {
        final result = await ref
            .read(inventoryDistributionRepositoryProvider)
            .approveReplacement(
              query: ref.read(phase4QueryProvider),
              requestId: requestId,
            );
        _invalidateDistributionReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final approveReplacementProvider =
    AsyncNotifierProvider<ApproveReplacementNotifier, InvReplacementRequest?>(
  ApproveReplacementNotifier.new,
);

class FulfillReplacementNotifier extends AsyncNotifier<InvReplacementRequest?> {
  @override
  FutureOr<InvReplacementRequest?> build() => null;

  Future<InvReplacementRequest?> execute({required String requestId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventoryDistribution(ref);
      try {
        final result = await ref
            .read(inventoryDistributionRepositoryProvider)
            .fulfillReplacement(
              query: ref.read(phase4QueryProvider),
              requestId: requestId,
            );
        _invalidateDistributionReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final fulfillReplacementProvider =
    AsyncNotifierProvider<FulfillReplacementNotifier, InvReplacementRequest?>(
  FulfillReplacementNotifier.new,
);

class RejectReplacementNotifier extends AsyncNotifier<InvReplacementRequest?> {
  @override
  FutureOr<InvReplacementRequest?> build() => null;

  Future<InvReplacementRequest?> execute({
    required String requestId,
    String? reason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventoryDistribution(ref);
      try {
        final result = await ref
            .read(inventoryDistributionRepositoryProvider)
            .rejectReplacement(
              query: ref.read(phase4QueryProvider),
              requestId: requestId,
              reason: reason,
            );
        _invalidateDistributionReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final rejectReplacementProvider =
    AsyncNotifierProvider<RejectReplacementNotifier, InvReplacementRequest?>(
  RejectReplacementNotifier.new,
);
