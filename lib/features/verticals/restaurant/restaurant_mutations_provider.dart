import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'restaurant_models.dart';
import 'restaurant_providers.dart';

void assertManageRestaurant(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null || !permissions.has(Permission.manageRestaurantHospitality)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage restaurant.',
        code: 'RBAC_MANAGE_RESTAURANT',
      ),
    );
  }
}

void _invalidateRestaurantReads(Ref ref) {
  ref.invalidate(restaurantDashboardProvider);
  ref.invalidate(restaurantIntelligenceProvider);
}

class CreateRestaurantOrderNotifier extends AsyncNotifier<RestaurantOrder?> {
  @override
  FutureOr<RestaurantOrder?> build() => null;

  Future<RestaurantOrder?> execute({
    required String tableId,
    required String items,
    required String notes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageRestaurant(ref);
      try {
        final result = await ref.read(restaurantRepositoryProvider).createRestaurantOrder(
              query: ref.read(repositoryQueryProvider),
              tableId: tableId,
              items: items,
              notes: notes,
            );
        _invalidateRestaurantReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createRestaurantOrderProvider =
    AsyncNotifierProvider<CreateRestaurantOrderNotifier, RestaurantOrder?>(CreateRestaurantOrderNotifier.new);

class UpdateKitchenTicketNotifier extends AsyncNotifier<KitchenTicket?> {
  @override
  FutureOr<KitchenTicket?> build() => null;

  Future<KitchenTicket?> execute({
    required String ticketId,
    required String status,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageRestaurant(ref);
      try {
        final result = await ref.read(restaurantRepositoryProvider).updateKitchenTicket(
              query: ref.read(repositoryQueryProvider),
              ticketId: ticketId,
              status: status,
            );
        _invalidateRestaurantReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final updateKitchenTicketProvider =
    AsyncNotifierProvider<UpdateKitchenTicketNotifier, KitchenTicket?>(UpdateKitchenTicketNotifier.new);
