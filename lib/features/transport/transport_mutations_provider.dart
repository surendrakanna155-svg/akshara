import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/interfaces/transport_repository.dart';
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
    if (state.isLoading) return state.valueOrNull;
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
    if (state.isLoading) return state.valueOrNull;
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
    if (state.isLoading) return state.valueOrNull;
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
    if (state.isLoading) return state.valueOrNull;
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
    if (state.isLoading) return state.valueOrNull;
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
    if (state.isLoading) return state.valueOrNull;
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
    if (state.isLoading) return state.valueOrNull;
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

// ─── TRN-1/TRN-2: vehicle CRUD ────────────────────────────────────────────────

class VehicleMutationNotifier extends AsyncNotifier<TransportVehicle?> {
  @override
  FutureOr<TransportVehicle?> build() => null;

  Future<TransportVehicle?> create(CreateTransportVehicleRequest request) =>
      _run((repo) => repo.createVehicle(
            query: ref.read(repositoryQueryProvider),
            request: request,
          ));

  Future<TransportVehicle?> edit(UpdateTransportVehicleRequest request) =>
      _run((repo) => repo.updateVehicle(
            query: ref.read(repositoryQueryProvider),
            request: request,
          ));

  Future<TransportVehicle?> _run(
    Future<TransportVehicle> Function(TransportRepository repo) action,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        final result = await action(ref.read(transportRepositoryProvider));
        ref
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

final vehicleMutationProvider =
    AsyncNotifierProvider<VehicleMutationNotifier, TransportVehicle?>(
  VehicleMutationNotifier.new,
);

class DeleteVehicleNotifier extends AsyncNotifier<bool> {
  @override
  FutureOr<bool> build() => false;

  Future<void> execute(DeleteTransportVehicleRequest request) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        await ref.read(transportRepositoryProvider).deleteVehicle(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(transportVehiclesFutureProvider)
          ..invalidate(transportDashboardFutureProvider);
        return true;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
  }
}

final deleteVehicleProvider =
    AsyncNotifierProvider<DeleteVehicleNotifier, bool>(
  DeleteVehicleNotifier.new,
);

// ─── TRN-1/TRN-2: driver CRUD ─────────────────────────────────────────────────

class DriverMutationNotifier extends AsyncNotifier<TransportDriver?> {
  @override
  FutureOr<TransportDriver?> build() => null;

  Future<TransportDriver?> create(CreateTransportDriverRequest request) =>
      _run((repo) => repo.createDriver(
            query: ref.read(repositoryQueryProvider),
            request: request,
          ));

  Future<TransportDriver?> edit(UpdateTransportDriverRequest request) =>
      _run((repo) => repo.updateDriver(
            query: ref.read(repositoryQueryProvider),
            request: request,
          ));

  Future<TransportDriver?> _run(
    Future<TransportDriver> Function(TransportRepository repo) action,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        final result = await action(ref.read(transportRepositoryProvider));
        ref.invalidate(transportDriversFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final driverMutationProvider =
    AsyncNotifierProvider<DriverMutationNotifier, TransportDriver?>(
  DriverMutationNotifier.new,
);

class DeleteDriverNotifier extends AsyncNotifier<bool> {
  @override
  FutureOr<bool> build() => false;

  Future<void> execute(DeleteTransportDriverRequest request) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        await ref.read(transportRepositoryProvider).deleteDriver(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref.invalidate(transportDriversFutureProvider);
        return true;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
  }
}

final deleteDriverProvider =
    AsyncNotifierProvider<DeleteDriverNotifier, bool>(
  DeleteDriverNotifier.new,
);

// ─── TRN-4: stop editor ───────────────────────────────────────────────────────

class StopEditorNotifier extends AsyncNotifier<TransportRoute?> {
  @override
  FutureOr<TransportRoute?> build() => null;

  Future<TransportRoute?> add(AddTransportStopRequest request) =>
      _run((repo) => repo.addStop(
            query: ref.read(repositoryQueryProvider),
            request: request,
          ));

  Future<TransportRoute?> editStop(UpdateTransportStopRequest request) =>
      _run((repo) => repo.updateStop(
            query: ref.read(repositoryQueryProvider),
            request: request,
          ));

  Future<TransportRoute?> remove(RemoveTransportStopRequest request) =>
      _run((repo) => repo.removeStop(
            query: ref.read(repositoryQueryProvider),
            request: request,
          ));

  Future<TransportRoute?> reorder(ReorderTransportStopsRequest request) =>
      _run((repo) => repo.reorderStops(
            query: ref.read(repositoryQueryProvider),
            request: request,
          ));

  Future<TransportRoute?> _run(
    Future<TransportRoute> Function(TransportRepository repo) action,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        final result = await action(ref.read(transportRepositoryProvider));
        ref.invalidate(transportRoutesFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final stopEditorProvider =
    AsyncNotifierProvider<StopEditorNotifier, TransportRoute?>(
  StopEditorNotifier.new,
);

// ─── TRN-5: bulk allocation ───────────────────────────────────────────────────

class BulkAllocateTransportNotifier
    extends AsyncNotifier<BulkAllocationResult?> {
  @override
  FutureOr<BulkAllocationResult?> build() => null;

  Future<BulkAllocationResult?> execute(
    BulkAllocateTransportRequest request,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        final result =
            await ref.read(transportRepositoryProvider).bulkAllocateTransport(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
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

final bulkAllocateTransportProvider = AsyncNotifierProvider<
    BulkAllocateTransportNotifier, BulkAllocationResult?>(
  BulkAllocateTransportNotifier.new,
);

// ─── TRN-8: document-expiry reminder ──────────────────────────────────────────

class SendDocumentExpiryReminderNotifier extends AsyncNotifier<int?> {
  @override
  FutureOr<int?> build() => null;

  Future<int?> execute(
    SendTransportDocumentExpiryReminderRequest request,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        return await ref
            .read(transportRepositoryProvider)
            .sendTransportDocumentExpiryReminder(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final sendDocumentExpiryReminderProvider =
    AsyncNotifierProvider<SendDocumentExpiryReminderNotifier, int?>(
  SendDocumentExpiryReminderNotifier.new,
);

// ─── TRN-9: raise a Finance transport-fee demand ──────────────────────────────

class RaiseTransportDemandNotifier
    extends AsyncNotifier<TransportDemandResult?> {
  @override
  FutureOr<TransportDemandResult?> build() => null;

  Future<TransportDemandResult?> execute(
    RaiseTransportDemandRequest request,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageTransport(ref);
      try {
        return await ref
            .read(transportRepositoryProvider)
            .raiseTransportDemand(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final raiseTransportDemandProvider = AsyncNotifierProvider<
    RaiseTransportDemandNotifier, TransportDemandResult?>(
  RaiseTransportDemandNotifier.new,
);
