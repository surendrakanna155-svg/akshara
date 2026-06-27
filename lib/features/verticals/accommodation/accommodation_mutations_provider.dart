import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'accommodation_models.dart';
import 'accommodation_providers.dart';

void assertManageAccommodation(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null || !permissions.has(Permission.manageAccommodation)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage accommodation.',
        code: 'RBAC_MANAGE_ACCOMMODATION',
      ),
    );
  }
}

void _invalidateAccommodationReads(Ref ref) {
  ref.invalidate(accommodationDashboardProvider);
  ref.invalidate(accommodationIntelligenceProvider);
}

class AllocateRoomNotifier extends AsyncNotifier<AccommodationAllocation?> {
  @override
  FutureOr<AccommodationAllocation?> build() => null;

  Future<AccommodationAllocation?> execute({
    required String residentId,
    required String roomId,
    required DateTime startDate,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageAccommodation(ref);
      try {
        final result = await ref.read(accommodationRepositoryProvider).allocateRoom(
              query: ref.read(repositoryQueryProvider),
              residentId: residentId,
              roomId: roomId,
              startDate: startDate,
            );
        _invalidateAccommodationReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final allocateRoomProvider =
    AsyncNotifierProvider<AllocateRoomNotifier, AccommodationAllocation?>(AllocateRoomNotifier.new);

class RegisterResidentNotifier extends AsyncNotifier<Resident?> {
  @override
  FutureOr<Resident?> build() => null;

  Future<Resident?> execute({
    required String name,
    required String detail,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageAccommodation(ref);
      try {
        final result = await ref.read(accommodationRepositoryProvider).registerResident(
              query: ref.read(repositoryQueryProvider),
              name: name,
              detail: detail,
            );
        _invalidateAccommodationReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final registerResidentProvider =
    AsyncNotifierProvider<RegisterResidentNotifier, Resident?>(RegisterResidentNotifier.new);
