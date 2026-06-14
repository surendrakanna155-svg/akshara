import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/interfaces/communication_repository.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'hr_audit.dart';
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

void assertApproveHrLeave(Ref ref) {
  assertManageHr(ref);
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

class ApproveHrLeaveNotifier extends AsyncNotifier<HrLeaveRequest?> {
  @override
  FutureOr<HrLeaveRequest?> build() => null;

  Future<HrLeaveRequest?> execute({
    required String leaveRequestId,
    required ApproveLeaveRequest request,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertApproveHrLeave(ref);
      try {
        final result = await ref.read(hrRepositoryProvider).approveLeaveRequest(
              query: ref.read(repositoryQueryProvider),
              leaveRequestId: leaveRequestId,
              request: request,
            );
        await recordHrAudit(
          ref,
          type: AuditEventType.leaveRequestApproved,
          employeeId: result.employeeId,
          metadata: {'leaveRequestId': result.id},
        );
        await ref.read(communicationRepositoryProvider).sendBroadcast(
              query: ref.read(repositoryQueryProvider),
              request: BroadcastRequest(
                audience: 'hr_staff',
                title: 'Leave approved',
                body:
                    '${result.employeeName}\'s leave has been approved by ${result.approver}.',
              ),
            );
        ref
          ..invalidate(hrLeaveFutureProvider)
          ..invalidate(hrDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final approveHrLeaveProvider =
    AsyncNotifierProvider<ApproveHrLeaveNotifier, HrLeaveRequest?>(
  ApproveHrLeaveNotifier.new,
);

class RejectHrLeaveNotifier extends AsyncNotifier<HrLeaveRequest?> {
  @override
  FutureOr<HrLeaveRequest?> build() => null;

  Future<HrLeaveRequest?> execute({
    required String leaveRequestId,
    required ApproveLeaveRequest request,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertApproveHrLeave(ref);
      try {
        final result = await ref.read(hrRepositoryProvider).rejectLeaveRequest(
              query: ref.read(repositoryQueryProvider),
              leaveRequestId: leaveRequestId,
              request: request,
            );
        await recordHrAudit(
          ref,
          type: AuditEventType.leaveRequestRejected,
          employeeId: result.employeeId,
          metadata: {'leaveRequestId': result.id},
        );
        await ref.read(communicationRepositoryProvider).sendBroadcast(
              query: ref.read(repositoryQueryProvider),
              request: BroadcastRequest(
                audience: 'hr_staff',
                title: 'Leave rejected',
                body:
                    '${result.employeeName}\'s leave has been rejected. Comment: ${request.comment.trim().isEmpty ? 'No comment' : request.comment.trim()}',
              ),
            );
        ref
          ..invalidate(hrLeaveFutureProvider)
          ..invalidate(hrDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final rejectHrLeaveProvider =
    AsyncNotifierProvider<RejectHrLeaveNotifier, HrLeaveRequest?>(
  RejectHrLeaveNotifier.new,
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

class CreateHrEmployeeNotifier extends AsyncNotifier<HrEmployee?> {
  @override
  FutureOr<HrEmployee?> build() => null;

  Future<HrEmployee?> execute(CreateHrEmployeeRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageHr(ref);
      try {
        final result = await ref.read(hrRepositoryProvider).createEmployee(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        await recordHrAudit(
          ref,
          type: AuditEventType.employeeCreated,
          employeeId: result.id,
          metadata: {
            'employeeCode': result.employeeCode,
            'name': result.name,
          },
        );
        ref
          ..invalidate(hrEmployeesFutureProvider)
          ..invalidate(hrDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createHrEmployeeProvider =
    AsyncNotifierProvider<CreateHrEmployeeNotifier, HrEmployee?>(
  CreateHrEmployeeNotifier.new,
);

class UpdateHrEmployeeNotifier extends AsyncNotifier<HrEmployee?> {
  @override
  FutureOr<HrEmployee?> build() => null;

  Future<HrEmployee?> execute(UpdateHrEmployeeRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageHr(ref);
      try {
        final result = await ref.read(hrRepositoryProvider).updateEmployee(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        await recordHrAudit(
          ref,
          type: AuditEventType.employeeUpdated,
          employeeId: result.id,
          metadata: {'name': result.name},
        );
        ref
          ..invalidate(hrEmployeesFutureProvider)
          ..invalidate(hrEmployeeDetailFutureProvider(request.employeeId))
          ..invalidate(hrDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final updateHrEmployeeProvider =
    AsyncNotifierProvider<UpdateHrEmployeeNotifier, HrEmployee?>(
  UpdateHrEmployeeNotifier.new,
);

class SetHrEmployeeStatusNotifier extends AsyncNotifier<HrEmployee?> {
  @override
  FutureOr<HrEmployee?> build() => null;

  Future<HrEmployee?> execute(SetHrEmployeeStatusRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageHr(ref);
      try {
        final result = await ref.read(hrRepositoryProvider).setEmployeeStatus(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        await recordHrAudit(
          ref,
          type: AuditEventType.employeeStatusChanged,
          employeeId: result.id,
          metadata: {'status': result.status.name},
        );
        ref
          ..invalidate(hrEmployeesFutureProvider)
          ..invalidate(hrEmployeeDetailFutureProvider(request.employeeId))
          ..invalidate(hrDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final setHrEmployeeStatusProvider =
    AsyncNotifierProvider<SetHrEmployeeStatusNotifier, HrEmployee?>(
  SetHrEmployeeStatusNotifier.new,
);
