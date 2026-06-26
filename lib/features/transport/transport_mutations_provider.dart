import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'transport_audit.dart';
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

class RecordTransportAttendanceNotifier
    extends AsyncNotifier<TransportAttendanceRecord?> {
  @override
  FutureOr<TransportAttendanceRecord?> build() => null;

  Future<TransportAttendanceRecord?> execute(
    RecordTransportAttendanceRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        final result =
            await ref.read(transportRepositoryProvider).recordAttendance(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        await recordTransportAudit(
          ref,
          type: AuditEventType.transportAttendanceRecorded,
          metadata: {
            'attendanceId': result.id,
            'status': result.status.name,
          },
        );
        ref
          ..invalidate(transportAttendanceFutureProvider)
          ..invalidate(transportDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final recordTransportAttendanceProvider = AsyncNotifierProvider<
    RecordTransportAttendanceNotifier, TransportAttendanceRecord?>(
  RecordTransportAttendanceNotifier.new,
);

class AssignStudentTransportNotifier
    extends AsyncNotifier<StudentTransportAllocation?> {
  @override
  FutureOr<StudentTransportAllocation?> build() => null;

  Future<StudentTransportAllocation?> execute(
    AssignStudentTransportRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        final result =
            await ref.read(transportRepositoryProvider).assignStudentTransport(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        await recordTransportAudit(
          ref,
          type: AuditEventType.transportStudentAssigned,
          allocationId: result.id,
          metadata: {
            'routeId': result.routeId,
            'busNumber': result.busNumber,
            'sisStudentId': result.sisStudentId,
          },
        );
        ref
          ..invalidate(transportAllocationsFutureProvider)
          ..invalidate(transportRoutesFutureProvider)
          ..invalidate(transportVehiclesFutureProvider)
          ..invalidate(transportDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final assignStudentTransportProvider = AsyncNotifierProvider<
    AssignStudentTransportNotifier, StudentTransportAllocation?>(
  AssignStudentTransportNotifier.new,
);

class TransferStudentTransportNotifier
    extends AsyncNotifier<StudentTransportAllocation?> {
  @override
  FutureOr<StudentTransportAllocation?> build() => null;

  Future<StudentTransportAllocation?> execute(
    TransferStudentTransportRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        final result = await ref
            .read(transportRepositoryProvider)
            .transferStudentTransport(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        await recordTransportAudit(
          ref,
          type: AuditEventType.transportStudentTransferred,
          allocationId: result.id,
          metadata: {
            'routeId': result.routeId,
            'busNumber': result.busNumber,
          },
        );
        ref
          ..invalidate(transportAllocationsFutureProvider)
          ..invalidate(transportRoutesFutureProvider)
          ..invalidate(transportVehiclesFutureProvider)
          ..invalidate(transportDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final transferStudentTransportProvider = AsyncNotifierProvider<
    TransferStudentTransportNotifier, StudentTransportAllocation?>(
  TransferStudentTransportNotifier.new,
);

class RemoveStudentTransportNotifier
    extends AsyncNotifier<StudentTransportAllocation?> {
  @override
  FutureOr<StudentTransportAllocation?> build() => null;

  Future<StudentTransportAllocation?> execute(
    RemoveStudentTransportRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        final result =
            await ref.read(transportRepositoryProvider).removeStudentTransport(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        await recordTransportAudit(
          ref,
          type: AuditEventType.transportStudentRemoved,
          allocationId: result.id,
          metadata: {'sisStudentId': result.sisStudentId},
        );
        ref
          ..invalidate(transportAllocationsFutureProvider)
          ..invalidate(transportRoutesFutureProvider)
          ..invalidate(transportVehiclesFutureProvider)
          ..invalidate(transportDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final removeStudentTransportProvider = AsyncNotifierProvider<
    RemoveStudentTransportNotifier, StudentTransportAllocation?>(
  RemoveStudentTransportNotifier.new,
);

class NotifyRouteDelayNotifier
    extends AsyncNotifier<TransportDelayNotificationResult?> {
  @override
  FutureOr<TransportDelayNotificationResult?> build() => null;

  Future<TransportDelayNotificationResult?> execute(
    NotifyRouteDelayRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        final result =
            await ref.read(transportRepositoryProvider).notifyRouteDelay(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        await recordTransportAudit(
          ref,
          type: AuditEventType.transportDelayNotified,
          metadata: {
            'routeId': request.routeId,
            'recipientCount': '${result.recipientCount}',
          },
        );
        ref.invalidate(transportTrackingFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final notifyRouteDelayProvider = AsyncNotifierProvider<NotifyRouteDelayNotifier,
    TransportDelayNotificationResult?>(
  NotifyRouteDelayNotifier.new,
);
