import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'transport_models.dart';
import 'transport_providers.dart';
import 'transport_requests.dart';

void assertManageTransport(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null || !perms.has(Permission.manageTransport)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage transport.',
        code: 'RBAC_MANAGE_TRANSPORT',
      ),
    );
  }
}

class CreateTransportRouteNotifier extends AsyncNotifier<TransportRoute?> {
  @override
  FutureOr<TransportRoute?> build() => null;

  Future<TransportRoute?> execute(CreateTransportRouteRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        final result = await ref.read(transportRepositoryProvider).createRoute(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref.invalidate(transportRoutesFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createTransportRouteProvider =
    AsyncNotifierProvider<CreateTransportRouteNotifier, TransportRoute?>(
  CreateTransportRouteNotifier.new,
);

class ActivateTransportRouteNotifier extends AsyncNotifier<TransportRoute?> {
  @override
  FutureOr<TransportRoute?> build() => null;

  Future<TransportRoute?> execute(
    ActivateTransportRouteRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        final result = await ref.read(transportRepositoryProvider).activateRoute(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref.invalidate(transportRoutesFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final activateTransportRouteProvider =
    AsyncNotifierProvider<ActivateTransportRouteNotifier, TransportRoute?>(
  ActivateTransportRouteNotifier.new,
);
