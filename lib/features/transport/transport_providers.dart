import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tenant/tenant_provider.dart';
import '../../core/providers/repository_future.dart';
import '../../core/repositories/paginated_result.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/repositories/repository_providers.dart';
import '../../shared/async/erp_async_state.dart';
import 'transport_document_expiry.dart';
import 'transport_models.dart';

// TR-01 Dashboard
final transportDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final transportDashboardErrorProvider = StateProvider<bool>((ref) => false);
final transportDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final transportDashboardFilterProvider = StateProvider<int>((ref) => 0);

final transportDashboardFutureProvider = FutureProvider<TransportDashboardData>((ref) async {
return await ref.read(transportRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

final transportDashboardProvider = Provider<TransportDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(transportDashboardFutureProvider),
    manualLoading: ref.watch(transportDashboardLoadingProvider), manualError: ref.watch(transportDashboardErrorProvider), manualEmpty: ref.watch(transportDashboardEmptyProvider),
  );
});

final transportDashboardViewStateProvider =
    Provider<ErpViewState<TransportDashboardData>>((ref) {
  return resolveErpAsync(
    ref.watch(transportDashboardFutureProvider),
    forceLoading: ref.watch(transportDashboardLoadingProvider),
    forceError: ref.watch(transportDashboardErrorProvider),
    forceEmpty: ref.watch(transportDashboardEmptyProvider),
  );
});

// TR-02 Routes
final transportRoutesLoadingProvider = StateProvider<bool>((ref) => false);
final transportRoutesErrorProvider = StateProvider<bool>((ref) => false);
final transportRoutesEmptyProvider = StateProvider<bool>((ref) => false);
final transportRoutesFilterProvider = StateProvider<int>((ref) => 0);
final transportSelectedRouteIdProvider = StateProvider<String?>((ref) => null);
final transportRoutesPageProvider = StateProvider<int>((ref) => 1);

final transportRoutesQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(transportRoutesPageProvider);
  return baseQuery.withPage(page);
});

final transportRoutesFutureProvider =
    FutureProvider<PaginatedResult<TransportRoute>>((ref) async {
  return ref.read(transportRepositoryProvider).getRoutes(
        query: ref.watch(transportRoutesQueryProvider),
      );
});

final transportRoutesPageResultProvider =
    Provider<PaginatedResult<TransportRoute>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(transportRoutesFutureProvider),
    manualLoading: ref.watch(transportRoutesLoadingProvider),
    manualError: ref.watch(transportRoutesErrorProvider),
    manualEmpty: ref.watch(transportRoutesEmptyProvider),
  );
});

final transportRoutesProvider = Provider<List<TransportRoute>>((ref) {
  return ref.watch(transportRoutesPageResultProvider)?.items ?? const [];
});

final transportFilteredRoutesProvider = Provider<List<TransportRoute>>((ref) {
  final routes = ref.watch(transportRoutesProvider);
  final filterIndex = ref.watch(transportRoutesFilterProvider);
  return switch (filterIndex) {
    1 => routes
        .where((r) => r.status == TransportRouteStatus.active)
        .toList(),
    2 => routes
        .where((r) => r.status == TransportRouteStatus.draft)
        .toList(),
    3 => routes
        .where((r) => r.status == TransportRouteStatus.inactive)
        .toList(),
    _ => routes,
  };
});

// TR-03 Vehicles
final transportVehiclesLoadingProvider = StateProvider<bool>((ref) => false);
final transportVehiclesErrorProvider = StateProvider<bool>((ref) => false);
final transportVehiclesEmptyProvider = StateProvider<bool>((ref) => false);
final transportVehiclesFilterProvider = StateProvider<int>((ref) => 0);
final transportVehiclesPageProvider = StateProvider<int>((ref) => 1);

final transportVehiclesQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(transportVehiclesPageProvider);
  return baseQuery.withPage(page);
});

final transportVehiclesFutureProvider =
    FutureProvider<PaginatedResult<TransportVehicle>>((ref) async {
  return ref.read(transportRepositoryProvider).getVehicles(
        query: ref.watch(transportVehiclesQueryProvider),
      );
});

final transportVehiclesPageResultProvider =
    Provider<PaginatedResult<TransportVehicle>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(transportVehiclesFutureProvider),
    manualLoading: ref.watch(transportVehiclesLoadingProvider),
    manualError: ref.watch(transportVehiclesErrorProvider),
    manualEmpty: ref.watch(transportVehiclesEmptyProvider),
  );
});

final transportVehiclesProvider = Provider<List<TransportVehicle>?>((ref) {
  return ref.watch(transportVehiclesPageResultProvider)?.items ?? const [];
});

final transportFilteredVehiclesProvider = Provider<List<TransportVehicle>>(
  (ref) {
    final vehicles = ref.watch(transportVehiclesProvider);
    if (vehicles == null) return const [];
    final filterIndex = ref.watch(transportVehiclesFilterProvider);
    return switch (filterIndex) {
      1 => vehicles
          .where((v) => v.status == TransportVehicleStatus.active)
          .toList(),
      2 => vehicles
          .where((v) => v.status == TransportVehicleStatus.maintenance)
          .toList(),
      3 => vehicles
          .where((v) => v.status == TransportVehicleStatus.retired)
          .toList(),
      _ => vehicles,
    };
  },
);

// TR-04 Drivers
final transportDriversLoadingProvider = StateProvider<bool>((ref) => false);
final transportDriversErrorProvider = StateProvider<bool>((ref) => false);
final transportDriversEmptyProvider = StateProvider<bool>((ref) => false);
final transportDriversFilterProvider = StateProvider<int>((ref) => 0);
final transportDriversPageProvider = StateProvider<int>((ref) => 1);

final transportDriversQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(transportDriversPageProvider);
  return baseQuery.withPage(page);
});

final transportDriversFutureProvider =
    FutureProvider<PaginatedResult<TransportDriver>>((ref) async {
  return ref.read(transportRepositoryProvider).getDrivers(
        query: ref.watch(transportDriversQueryProvider),
      );
});

final transportDriversPageResultProvider =
    Provider<PaginatedResult<TransportDriver>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(transportDriversFutureProvider),
    manualLoading: ref.watch(transportDriversLoadingProvider),
    manualError: ref.watch(transportDriversErrorProvider),
    manualEmpty: ref.watch(transportDriversEmptyProvider),
  );
});

final transportDriversProvider = Provider<List<TransportDriver>?>((ref) {
  return ref.watch(transportDriversPageResultProvider)?.items ?? const [];
});

final transportFilteredDriversProvider = Provider<List<TransportDriver>>(
  (ref) {
    final drivers = ref.watch(transportDriversProvider);
    if (drivers == null) return const [];
    final filterIndex = ref.watch(transportDriversFilterProvider);
    return switch (filterIndex) {
      1 => drivers
          .where((d) => d.status == TransportDriverStatus.active)
          .toList(),
      2 => drivers
          .where((d) => d.status == TransportDriverStatus.onLeave)
          .toList(),
      3 => drivers
          .where((d) => d.status == TransportDriverStatus.inactive)
          .toList(),
      _ => drivers,
    };
  },
);

// TR-05 Allocation
final transportAllocationLoadingProvider = StateProvider<bool>((ref) => false);
final transportAllocationErrorProvider = StateProvider<bool>((ref) => false);
final transportAllocationEmptyProvider = StateProvider<bool>((ref) => false);
final transportAllocationFilterProvider = StateProvider<int>((ref) => 0);
final transportAllocationsPageProvider = StateProvider<int>((ref) => 1);

final transportAllocationsQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(transportAllocationsPageProvider);
  return baseQuery.withPage(page);
});

final transportAllocationsFutureProvider =
    FutureProvider<PaginatedResult<StudentTransportAllocation>>((ref) async {
  return ref.read(transportRepositoryProvider).getAllocations(
        query: ref.watch(transportAllocationsQueryProvider),
      );
});

final transportAllocationsPageResultProvider =
    Provider<PaginatedResult<StudentTransportAllocation>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(transportAllocationsFutureProvider),
    manualLoading: ref.watch(transportAllocationLoadingProvider),
    manualError: ref.watch(transportAllocationErrorProvider),
    manualEmpty: ref.watch(transportAllocationEmptyProvider),
  );
});

final transportAllocationsProvider =
    Provider<List<StudentTransportAllocation>?>((ref) {
  return ref.watch(transportAllocationsPageResultProvider)?.items;
});

final transportFilteredAllocationsProvider =
    Provider<List<StudentTransportAllocation>>((ref) {
  final allocations = ref.watch(transportAllocationsProvider);
  if (allocations == null) return const [];
  final filterIndex = ref.watch(transportAllocationFilterProvider);
  return switch (filterIndex) {
    1 => allocations
        .where((a) => a.routeName.startsWith('Route 12'))
        .toList(growable: false),
    2 => allocations
        .where((a) => a.routeName.startsWith('Route 08'))
        .toList(growable: false),
    3 => allocations.where((a) => !a.isAssigned).toList(growable: false),
    _ => allocations,
  };
});

// TR-06 Attendance
final transportAttendanceLoadingProvider = StateProvider<bool>((ref) => false);
final transportAttendanceErrorProvider = StateProvider<bool>((ref) => false);
final transportAttendanceEmptyProvider = StateProvider<bool>((ref) => false);
final transportAttendanceFilterProvider = StateProvider<int>((ref) => 0);
final transportAttendancePageProvider = StateProvider<int>((ref) => 1);

final transportAttendanceQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(transportAttendancePageProvider);
  return baseQuery.withPage(page);
});

final transportAttendanceFutureProvider =
    FutureProvider<PaginatedResult<TransportAttendanceRecord>>((ref) async {
  return ref.read(transportRepositoryProvider).getAttendanceRecords(
        query: ref.watch(transportAttendanceQueryProvider),
      );
});

final transportAttendancePageResultProvider =
    Provider<PaginatedResult<TransportAttendanceRecord>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(transportAttendanceFutureProvider),
    manualLoading: ref.watch(transportAttendanceLoadingProvider),
    manualError: ref.watch(transportAttendanceErrorProvider),
    manualEmpty: ref.watch(transportAttendanceEmptyProvider),
  );
});

final transportAttendanceProvider =
    Provider<List<TransportAttendanceRecord>?>((ref) {
  return ref.watch(transportAttendancePageResultProvider)?.items;
});

final transportFilteredAttendanceProvider =
    Provider<List<TransportAttendanceRecord>>((ref) {
  final records = ref.watch(transportAttendanceProvider);
  if (records == null) return const [];
  final filterIndex = ref.watch(transportAttendanceFilterProvider);
  return switch (filterIndex) {
    1 => records
        .where((r) => r.status == TransportAttendanceStatus.picked)
        .toList(),
    2 => records
        .where((r) => r.status == TransportAttendanceStatus.waiting)
        .toList(),
    3 => records
        .where((r) => r.status == TransportAttendanceStatus.absent)
        .toList(),
    _ => records,
  };
});

// TR-07 Tracking
final transportTrackingLoadingProvider = StateProvider<bool>((ref) => false);
final transportTrackingErrorProvider = StateProvider<bool>((ref) => false);

final transportTrackingFutureProvider =
    FutureProvider<TransportTrackingPlaceholderData>((ref) async {
  return ref.read(transportRepositoryProvider).getTrackingPlaceholder(
        query: ref.watch(repositoryQueryProvider),
      );
});

final transportTrackingProvider =
    Provider<TransportTrackingPlaceholderData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(transportTrackingFutureProvider),
    manualLoading: ref.watch(transportTrackingLoadingProvider),
    manualError: ref.watch(transportTrackingErrorProvider),
    manualEmpty: false,
  );
});

// TR-08 Reports
final transportReportsLoadingProvider = StateProvider<bool>((ref) => false);
final transportReportsErrorProvider = StateProvider<bool>((ref) => false);
final transportReportsEmptyProvider = StateProvider<bool>((ref) => false);

final transportReportsFutureProvider = FutureProvider<TransportReportsData>((ref) async {
return await ref.read(transportRepositoryProvider).getReports(query: ref.watch(repositoryQueryProvider));
});

final transportReportsProvider = Provider<TransportReportsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(transportReportsFutureProvider),
    manualLoading: ref.watch(transportReportsLoadingProvider), manualError: ref.watch(transportReportsErrorProvider), manualEmpty: ref.watch(transportReportsEmptyProvider),
  );
});

// TR-09 Settings
final transportSettingsLoadingProvider = StateProvider<bool>((ref) => false);
final transportSettingsErrorProvider = StateProvider<bool>((ref) => false);

final transportSettingsFutureProvider = FutureProvider<TransportSettingsData>((ref) async {
return await ref.read(transportRepositoryProvider).getSettings(query: ref.watch(repositoryQueryProvider));
});

final transportSettingsProvider = Provider<TransportSettingsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(transportSettingsFutureProvider),
    manualLoading: ref.watch(transportSettingsLoadingProvider), manualError: ref.watch(transportSettingsErrorProvider), manualEmpty: false,
  );
});

// TRN-3 — stop-wise route roster (per route id).
final transportRouteRosterProvider =
    FutureProvider.family<RouteRoster, String>((ref, routeId) async {
  return ref.read(transportRepositoryProvider).getRouteRoster(
        query: ref.watch(repositoryQueryProvider),
        routeId: routeId,
      );
});

// TRN-2/TRN-8 — document-expiry tracker (derived from vehicles + drivers).
final transportDocumentExpiriesProvider =
    FutureProvider<List<TransportDocumentExpiry>>((ref) async {
  final repo = ref.read(transportRepositoryProvider);
  final query = ref.watch(repositoryQueryProvider);
  final vehicles = await repo.getVehicles(query: query);
  final drivers = await repo.getDrivers(query: query);
  return TransportDocumentExpiryScanner.scan(
    vehicles: vehicles.items,
    drivers: drivers.items,
  );
});
