import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'hr_models.dart';
import 'hr_providers.dart';
import 'hr_requests.dart';

void assertManageHr(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null || !perms.has(Permission.manageHr)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage HR.',
        code: 'RBAC_MANAGE_HR',
      ),
    );
  }
}

class CreateHrLeaveNotifier extends AsyncNotifier<HrLeaveRequest?> {
  @override
  FutureOr<HrLeaveRequest?> build() => null;

  Future<HrLeaveRequest?> execute(CreateHrLeaveRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageHr(ref);
      try {
        final result = await ref.read(hrRepositoryProvider).createLeaveRequest(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref.invalidate(hrLeaveFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createHrLeaveProvider =
    AsyncNotifierProvider<CreateHrLeaveNotifier, HrLeaveRequest?>(
  CreateHrLeaveNotifier.new,
);

class ProcessHrPayrollRunNotifier extends AsyncNotifier<HrPayrollRun?> {
  @override
  FutureOr<HrPayrollRun?> build() => null;

  Future<HrPayrollRun?> execute(ProcessHrPayrollRunRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageHr(ref);
      try {
        final result =
            await ref.read(hrRepositoryProvider).processPayrollRun(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        ref.invalidate(hrPayrollFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final processHrPayrollRunProvider =
    AsyncNotifierProvider<ProcessHrPayrollRunNotifier, HrPayrollRun?>(
  ProcessHrPayrollRunNotifier.new,
);
