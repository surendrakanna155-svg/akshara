import 'package:akshara_erp/features/transport/transport_models.dart';
import 'package:akshara_erp/features/transport/transport_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = createProviderTestContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('Transport providers', () {
    test('transportDashboardProvider returns dashboard data', () async {      await container.read(transportDashboardFutureProvider.future);

      final data = container.read(transportDashboardProvider);

      expect(data, isNotNull);
      expect(data!.kpis, hasLength(6));
      expect(data.vehicleAssignments, isNotEmpty);
    });

    test('transportDashboardProvider returns null when loading', () async {
      container = createProviderTestContainer(
        overrides: [
          transportDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );

      expect(container.read(transportDashboardProvider), isNull);
    });

    test('transportRoutesProvider returns routes', () async {
      await container.read(transportRoutesFutureProvider.future);

      final routes = container.read(transportRoutesProvider);

      expect(routes, hasLength(4));
    });

    test('transportFilteredRoutesProvider filters active routes', () async {
      container = createProviderTestContainer(
        overrides: [
          transportRoutesFilterProvider.overrideWith((ref) => 1),
        ],
      );

      final filtered = container.read(transportFilteredRoutesProvider);
      expect(
        filtered.every((r) => r.status == TransportRouteStatus.active),
        isTrue,
      );
    });

    test('transportVehiclesProvider returns vehicles', () async {      await container.read(transportVehiclesFutureProvider.future);

      final vehicles = container.read(transportVehiclesProvider);

      expect(vehicles, isNotNull);
      expect(vehicles!, hasLength(4));
    });

    test('transportDriversProvider returns drivers', () async {      await container.read(transportDriversFutureProvider.future);

      final drivers = container.read(transportDriversProvider);

      expect(drivers, isNotNull);
      expect(drivers!, hasLength(4));
    });

    test('transportAllocationsProvider returns SIS-linked allocations', () async {      await container.read(transportAllocationsFutureProvider.future);

      final allocations = container.read(transportAllocationsProvider);

      expect(allocations, isNotNull);
      expect(allocations!.first.sisStudentId, startsWith('SIS-STU-'));
    });

    test('transportAttendanceProvider returns attendance records', () async {      await container.read(transportAttendanceFutureProvider.future);

      final records = container.read(transportAttendanceProvider);

      expect(records, isNotNull);
      expect(records!, hasLength(4));
    });

    test('transportFilteredAttendanceProvider filters picked', () async {
      container = createProviderTestContainer(
        overrides: [
          transportAttendanceFilterProvider.overrideWith((ref) => 1),
        ],
      );

      final filtered = container.read(transportFilteredAttendanceProvider);
      expect(
        filtered.every((r) => r.status == TransportAttendanceStatus.picked),
        isTrue,
      );
    });

    test('transportTrackingProvider returns placeholder data', () async {      await container.read(transportTrackingFutureProvider.future);

      final data = container.read(transportTrackingProvider);

      expect(data, isNotNull);
      expect(data!.vehicles, hasLength(3));
      expect(data.mapPlaceholderLabel, isNotEmpty);
    });

    test('transportReportsProvider returns reports data', () async {      await container.read(transportReportsFutureProvider.future);

      final data = container.read(transportReportsProvider);

      expect(data, isNotNull);
      expect(data!.catalog, hasLength(6));
    });

    test('transportSettingsProvider returns settings sections', () async {      await container.read(transportSettingsFutureProvider.future);

      final data = container.read(transportSettingsProvider);

      expect(data, isNotNull);
      expect(data!.sections.length, greaterThan(3));
    });
  });
}
