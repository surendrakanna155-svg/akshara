import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/repositories/api/transport/v2/transport_v2_datasource.dart';
import '../../../core/repositories/api/transport/v2/transport_v2_repository.dart';
import '../../../core/repositories/repository_config.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'transport_v2_models.dart';

/// Transport v2 state.
///
/// No mock repository is wired here, deliberately. The legacy provider fell back
/// to `MockTransportRepository` whenever the API flag was off, which meant every
/// screen had a path where it looked like it worked against data that was never
/// persisted. v2 is API-only: if the backend is unreachable the UI says so.

final transportV2DataSourceProvider = Provider<TransportV2DataSource>(
  (ref) => TransportV2DataSource(ref.watch(dioProvider)),
);

final transportV2RepositoryProvider = Provider<TransportV2Repository>(
  (ref) => TransportV2Repository(ref.watch(transportV2DataSourceProvider)),
);

/// BUS-015 — the v2 relational store is per-school gated. Until a school is
/// migrated (BUS-030) its transport screens must keep reading the legacy path,
/// so every v2 screen checks this before issuing a request.
final transportV2EnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(transportApiEnabledProvider)) return false;
  return const bool.fromEnvironment(
    'TRANSPORT_RELATIONAL_STORE',
    defaultValue: false,
  );
});

/// The service date every v2 read is scoped to.
///
/// Assignment, capacity and readiness are all date-dependent (a substitute
/// covers *today*, the permanent driver returns *tomorrow*), so the date is
/// explicit state rather than an implicit `now()` buried in each call. An admin
/// arranging tomorrow's cover needs to see tomorrow.
final transportV2ServiceDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final transportV2ServiceDateIsoProvider = Provider<String>(
  (ref) => _iso(ref.watch(transportV2ServiceDateProvider)),
);

/// Routes for the active school on the selected service date.
final transportV2RoutesProvider = FutureProvider<RoutesResult>((ref) async {
  if (!ref.watch(transportV2EnabledProvider)) {
    return const RoutesResult(routes: [], isStale: false, cachedAt: null);
  }
  return ref.watch(transportV2RepositoryProvider).getRoutes(
        query: ref.watch(repositoryQueryProvider),
        serviceDate: ref.watch(transportV2ServiceDateIsoProvider),
      );
});

final transportV2StopsProvider = FutureProvider<StopsResult>((ref) async {
  if (!ref.watch(transportV2EnabledProvider)) {
    return const StopsResult(stops: [], isStale: false, cachedAt: null);
  }
  return ref.watch(transportV2RepositoryProvider).getStops(
        query: ref.watch(repositoryQueryProvider),
      );
});

/// Readiness for one route. Never cached — it gates publication (BUS-042).
final transportV2ReadinessProvider =
    FutureProvider.family<RouteReadinessV2, String>((ref, routeId) async {
  return ref.watch(transportV2RepositoryProvider).getRouteReadiness(
        query: ref.watch(repositoryQueryProvider),
        routeId: routeId,
      );
});

/// Routes with no resolvable crew for the selected date (BUS-050). This is the
/// signal that lets an admin arrange a substitute before 6 a.m. rather than
/// discovering the gap when a bus fails to arrive.
final transportV2UnstaffedProvider =
    FutureProvider<List<UnstaffedRouteV2>>((ref) async {
  if (!ref.watch(transportV2EnabledProvider)) return const [];
  return ref.watch(transportV2RepositoryProvider).getUnstaffedRoutes(
        query: ref.watch(repositoryQueryProvider),
        serviceDate: ref.watch(transportV2ServiceDateIsoProvider),
      );
});

// ─── Mutation state ──────────────────────────────────────────────────────────

/// Outcome of a v2 mutation.
///
/// Carries the backend's error CODE, not just a message. The codes are the
/// operator's instructions — ROUTE_INCOMPLETE lists what is missing,
/// STOP_HAS_ALLOCATIONS says who to move first, COMPLIANCE_BLOCKED names the
/// expired document. A screen that only had a message string would have to
/// string-match to decide whether to offer an override.
@immutable
class TransportV2MutationState {
  const TransportV2MutationState({
    this.isBusy = false,
    this.failure,
    this.successMessage,
  });

  final bool isBusy;
  final ApiFailure? failure;
  final String? successMessage;

  bool get hasError => failure != null;
  String? get errorCode => failure?.code;

  /// True when the backend deliberately refused, rather than failing to answer.
  /// Such a failure must NOT offer a retry — retrying changes nothing.
  bool get isDomainRefusal =>
      TransportV2ErrorCodes.isActionable(failure?.code) &&
      failure?.type != ApiFailureType.network &&
      failure?.type != ApiFailureType.timeout &&
      failure?.type != ApiFailureType.server;

  bool get isRetryable =>
      failure != null &&
      (failure!.type == ApiFailureType.network ||
          failure!.type == ApiFailureType.timeout ||
          failure!.type == ApiFailureType.server);
}

/// Runs v2 mutations and exposes a single busy/error surface for the screens.
class TransportV2Mutations extends StateNotifier<TransportV2MutationState> {
  TransportV2Mutations(this._ref) : super(const TransportV2MutationState());

  final Ref _ref;

  TransportV2Repository get _repo => _ref.read(transportV2RepositoryProvider);
  RepositoryQuery get _query => _ref.read(repositoryQueryProvider);

  /// Runs [action], then invalidates the affected reads so the UI reflects the
  /// backend's actual state rather than a locally-guessed one.
  Future<T?> _run<T>(Future<T> Function() action, {String? success}) async {
    state = const TransportV2MutationState(isBusy: true);
    try {
      final result = await action();
      _ref.invalidate(transportV2RoutesProvider);
      _ref.invalidate(transportV2StopsProvider);
      _ref.invalidate(transportV2UnstaffedProvider);
      state = TransportV2MutationState(successMessage: success);
      return result;
    } catch (error) {
      state = TransportV2MutationState(
        failure: error is ApiFailureException
            ? error.failure
            : apiFailureMapper.fromException(error),
      );
      return null;
    }
  }

  void clear() => state = const TransportV2MutationState();

  // Routes
  Future<String?> createRoute({
    required String name,
    required RouteV2Shift shift,
    RouteV2Direction direction = RouteV2Direction.pickup,
    String code = '',
    StopTime? defaultDepartureTime,
    StopTime? defaultReturnTime,
    int? distanceM,
  }) =>
      _run(
        () => _repo.createRoute(
          query: _query,
          name: name,
          shift: shift,
          direction: direction,
          code: code,
          defaultDepartureTime: defaultDepartureTime,
          defaultReturnTime: defaultReturnTime,
          distanceM: distanceM,
        ),
        success: 'Route created as a draft',
      );

  Future<void> updateRoute({
    required String routeId,
    String? name,
    String? code,
    RouteV2Shift? shift,
    RouteV2Direction? direction,
    StopTime? defaultDepartureTime,
    StopTime? defaultReturnTime,
    int? distanceM,
  }) =>
      _run(
        () => _repo.updateRoute(
          query: _query,
          routeId: routeId,
          name: name,
          code: code,
          shift: shift,
          direction: direction,
          defaultDepartureTime: defaultDepartureTime,
          defaultReturnTime: defaultReturnTime,
          distanceM: distanceM,
        ),
        success: 'Route updated',
      );

  Future<void> activateRoute(String routeId) => _run(
        () => _repo.activateRoute(query: _query, routeId: routeId),
        success: 'Route activated',
      );

  Future<int?> deactivateRoute(String routeId) => _run(
        () => _repo.deactivateRoute(query: _query, routeId: routeId),
        success: 'Route deactivated',
      );

  Future<void> deleteRoute(String routeId) => _run(
        () => _repo.deleteRoute(query: _query, routeId: routeId),
        success: 'Route deleted',
      );

  // Stops
  Future<String?> createStop({
    required String name,
    required GeoPoint location,
    int geofenceRadiusM = 100,
    String addressText = '',
    String landmark = '',
  }) =>
      _run(
        () => _repo.createStop(
          query: _query,
          name: name,
          location: location,
          geofenceRadiusM: geofenceRadiusM,
          addressText: addressText,
          landmark: landmark,
        ),
        success: 'Stop created',
      );

  Future<void> updateStop({
    required String stopId,
    String? name,
    GeoPoint? location,
    int? geofenceRadiusM,
    String? addressText,
    String? landmark,
  }) =>
      _run(
        () => _repo.updateStop(
          query: _query,
          stopId: stopId,
          name: name,
          location: location,
          geofenceRadiusM: geofenceRadiusM,
          addressText: addressText,
          landmark: landmark,
        ),
        success: 'Stop updated',
      );

  Future<void> deleteStop(String stopId) => _run(
        () => _repo.deleteStop(query: _query, stopId: stopId),
        success: 'Stop deleted',
      );

  Future<void> attachStop({
    required String routeId,
    required String stopId,
    StopTime? pickupTime,
    StopTime? dropTime,
  }) =>
      _run(
        () => _repo.attachStop(
          query: _query,
          routeId: routeId,
          stopId: stopId,
          pickupTime: pickupTime,
          dropTime: dropTime,
        ),
        success: 'Stop added to route',
      );

  Future<void> updateRouteStop({
    required String routeId,
    required String stopId,
    StopTime? pickupTime,
    StopTime? dropTime,
  }) =>
      _run(
        () => _repo.updateRouteStop(
          query: _query,
          routeId: routeId,
          stopId: stopId,
          pickupTime: pickupTime,
          dropTime: dropTime,
        ),
        success: 'Stop times updated',
      );

  Future<void> detachStop({required String routeId, required String stopId}) =>
      _run(
        () => _repo.detachStop(query: _query, routeId: routeId, stopId: stopId),
        success: 'Stop removed from route',
      );

  Future<void> reorderStops({
    required String routeId,
    required List<String> stopOrder,
  }) =>
      _run(
        () => _repo.reorderStops(
          query: _query,
          routeId: routeId,
          stopOrder: stopOrder,
        ),
        success: 'Stop order updated',
      );

  // Assignment
  Future<RouteAssignmentV2?> setAssignment({
    required String routeId,
    String? vehicleId,
    String? driverId,
    String? attendantId,
    String reason = '',
    bool allowNonCompliant = false,
  }) =>
      _run(
        () => _repo.setAssignment(
          query: _query,
          routeId: routeId,
          vehicleId: vehicleId,
          driverId: driverId,
          attendantId: attendantId,
          reason: reason,
          allowNonCompliant: allowNonCompliant,
        ),
        success: 'Bus and driver assigned',
      );

  Future<({RouteAssignmentV2 assignment, int tripsRebound})?> substitute({
    required String routeId,
    required String reason,
    String? vehicleId,
    String? driverId,
    String? effectiveFrom,
    String? effectiveTo,
    bool allowNonCompliant = false,
  }) =>
      _run(
        () => _repo.substituteAssignment(
          query: _query,
          routeId: routeId,
          reason: reason,
          vehicleId: vehicleId,
          driverId: driverId,
          effectiveFrom: effectiveFrom,
          effectiveTo: effectiveTo,
          allowNonCompliant: allowNonCompliant,
        ),
        success: 'Substitute assigned for the selected dates',
      );

  Future<int?> cancelSubstitute(String assignmentId) => _run(
        () => _repo.cancelSubstitute(query: _query, assignmentId: assignmentId),
        success: 'Substitution cancelled',
      );

  Future<List<UnstaffedRouteV2>?> setDriverAvailability({
    required String driverId,
    required String fromDate,
    required String toDate,
    String kind = 'leave',
    String reason = '',
  }) =>
      _run(
        () => _repo.setDriverAvailability(
          query: _query,
          driverId: driverId,
          fromDate: fromDate,
          toDate: toDate,
          kind: kind,
          reason: reason,
        ),
        success: 'Driver availability recorded',
      );
}

final transportV2MutationsProvider =
    StateNotifierProvider<TransportV2Mutations, TransportV2MutationState>(
  TransportV2Mutations.new,
);

/// Maps a v2 error code to the action the operator should take.
///
/// Kept beside the state so every screen gives the same guidance for the same
/// refusal. The legacy layer surfaced raw messages, so identical failures read
/// differently depending on which dialog you were in.
String transportV2Guidance(String? code) => switch (code) {
      TransportV2ErrorCodes.routeIncomplete =>
        'Finish the route setup before activating it.',
      TransportV2ErrorCodes.routeInUse =>
        'Deactivate this route instead — it has students or trip history.',
      TransportV2ErrorCodes.stopInUse =>
        'Remove this stop from its routes before deleting it.',
      TransportV2ErrorCodes.stopHasAllocations =>
        'Move the allocated students to another stop first.',
      TransportV2ErrorCodes.stopLocationRequired =>
        'Place this stop on the map before using it.',
      TransportV2ErrorCodes.stopLocationInvalid =>
        'That location is not valid. Drop the pin on the actual stop.',
      TransportV2ErrorCodes.capacityExceeded =>
        'The assigned bus is full. Assign a larger bus or override deliberately.',
      TransportV2ErrorCodes.complianceBlocked =>
        'Renew the expired document, or override deliberately (this is audited).',
      TransportV2ErrorCodes.driverUnavailable =>
        'This driver is on leave. Assign a substitute for those dates.',
      TransportV2ErrorCodes.driverDoubleBooked =>
        'This driver already runs another route in the same shift.',
      TransportV2ErrorCodes.vehicleDoubleBooked =>
        'This bus already runs another route in the same shift.',
      TransportV2ErrorCodes.vehicleInUse =>
        'Retire this bus instead — assignments or trips reference it.',
      TransportV2ErrorCodes.driverInUse =>
        'Deactivate this person instead — assignments or trips reference them.',
      TransportV2ErrorCodes.notASubstitute =>
        'Replace the permanent assignment rather than cancelling it.',
      TransportV2ErrorCodes.invalidTime =>
        'Enter a time like 07:05 or 7:05 AM.',
      TransportV2ErrorCodes.nothingToAssign =>
        'Choose a bus or a driver to assign.',
      _ => '',
    };
