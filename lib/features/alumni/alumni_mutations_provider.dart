import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'alumni_models.dart';
import 'alumni_providers.dart';
import 'alumni_requests.dart';

void assertManageAlumni(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null || !perms.has(Permission.manageAlumni)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage alumni.',
        code: 'RBAC_MANAGE_ALUMNI',
      ),
    );
  }
}

class AddAlumniNotifier extends AsyncNotifier<AlumniRecord?> {
  @override
  FutureOr<AlumniRecord?> build() => null;

  Future<AlumniRecord?> execute(AddAlumniRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageAlumni(ref);
      try {
        final result = await ref.read(alumniRepositoryProvider).addAlumni(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(alumniRegistryFutureProvider)
          ..invalidate(alumniDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final addAlumniProvider =
    AsyncNotifierProvider<AddAlumniNotifier, AlumniRecord?>(
  AddAlumniNotifier.new,
);

class CreateAlumniEventNotifier extends AsyncNotifier<AlumniEvent?> {
  @override
  FutureOr<AlumniEvent?> build() => null;

  Future<AlumniEvent?> execute(CreateAlumniEventRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageAlumni(ref);
      try {
        final result = await ref.read(alumniRepositoryProvider).createEvent(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(alumniEventsFutureProvider)
          ..invalidate(alumniDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createAlumniEventProvider =
    AsyncNotifierProvider<CreateAlumniEventNotifier, AlumniEvent?>(
  CreateAlumniEventNotifier.new,
);
