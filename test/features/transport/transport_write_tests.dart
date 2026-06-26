import 'package:akshara_erp/core/repositories/mock/mock_transport_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_transport_write_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/transport/transport_models.dart';
import 'package:akshara_erp/features/transport/transport_mutations_provider.dart';
import 'package:akshara_erp/features/transport/transport_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  setUp(() {
    MockTransportWriteStore.instance.reset();
  });

  group('Transport mock allocation writes', () {
    const query = RepositoryQuery.demo;

    test('assignStudentTransport enrolls unassigned student on route', () async {
      final repo = MockTransportRepository();

      final assigned = await repo.assignStudentTransport(
        query: query,
        request: const AssignStudentTransportRequest(
          allocationId: 'alloc_5',
          routeId: 'route_12',
          pickupStop: 'Lake View Colony',
          dropStop: 'Akshara Main Gate',
        ),
      );

      expect(assigned.routeId, 'route_12');
      expect(assigned.busNumber, 'BUS-07');
      expect(assigned.isAssigned, isTrue);

      final routes = await repo.getRoutes(query: query);
      final route = routes.items.firstWhere((r) => r.id == 'route_12');
      expect(route.studentCount, 3);

      final vehicles = await repo.getVehicles(query: query);
      final bus = vehicles.items.firstWhere((v) => v.busNumber == 'BUS-07');
      expect(bus.occupancyPercent, greaterThan(0));
    });

    test('transferStudentTransport moves student between routes', () async {
      final repo = MockTransportRepository();
      await repo.assignStudentTransport(
        query: query,
        request: const AssignStudentTransportRequest(
          allocationId: 'alloc_5',
          routeId: 'route_12',
          pickupStop: 'Lake View Colony',
          dropStop: 'Akshara Main Gate',
        ),
      );

      final transferred = await repo.transferStudentTransport(
        query: query,
        request: const TransferStudentTransportRequest(
          allocationId: 'alloc_5',
          targetRouteId: 'route_08',
          pickupStop: 'Hitech City',
          dropStop: 'Akshara Main Gate',
        ),
      );

      expect(transferred.routeId, 'route_08');
      expect(transferred.busNumber, 'BUS-03');

      final routes = await repo.getRoutes(query: query);
      expect(
        routes.items.firstWhere((r) => r.id == 'route_12').studentCount,
        2,
      );
      expect(
        routes.items.firstWhere((r) => r.id == 'route_08').studentCount,
        2,
      );
    });

    test('removeStudentTransport clears route assignment', () async {
      final repo = MockTransportRepository();
      await repo.assignStudentTransport(
        query: query,
        request: const AssignStudentTransportRequest(
          allocationId: 'alloc_5',
          routeId: 'route_12',
          pickupStop: 'Lake View Colony',
          dropStop: 'Akshara Main Gate',
        ),
      );

      final removed = await repo.removeStudentTransport(
        query: query,
        request: const RemoveStudentTransportRequest(allocationId: 'alloc_5'),
      );

      expect(removed.isAssigned, isFalse);
      expect(removed.routeName, 'Unassigned');

      final metrics = await repo.getOccupancyMetrics(query: query);
      expect(metrics.unassignedStudents, 2);
    });

    test('assignStudentTransport enforces vehicle capacity', () async {
      MockTransportWriteStore.instance.reset();
      final repo = MockTransportRepository();
      final store = MockTransportWriteStore.instance;
      final vehicles = (await repo.getVehicles(query: query)).items;
      store.vehicles = [
        for (final vehicle in vehicles)
          if (vehicle.busNumber == 'BUS-07')
            TransportVehicle(
              id: vehicle.id,
              busNumber: vehicle.busNumber,
              registration: vehicle.registration,
              capacity: 2,
              routeName: vehicle.routeName,
              gpsDeviceId: vehicle.gpsDeviceId,
              insuranceExpiry: vehicle.insuranceExpiry,
              fitnessExpiry: vehicle.fitnessExpiry,
              status: vehicle.status,
              occupancyPercent: vehicle.occupancyPercent,
            )
          else
            vehicle,
      ];

      expect(
        () => repo.assignStudentTransport(
          query: query,
          request: const AssignStudentTransportRequest(
            allocationId: 'alloc_5',
            routeId: 'route_12',
            pickupStop: 'Lake View Colony',
            dropStop: 'Akshara Main Gate',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Transport mock attendance + delay writes', () {
    const query = RepositoryQuery.demo;

    test('recordAttendance updates an existing record in place', () async {
      final repo = MockTransportRepository();
      final before = await repo.getAttendanceRecords(query: query);
      final target = before.items.firstWhere(
        (r) => r.status == TransportAttendanceStatus.waiting,
      );

      final updated = await repo.recordAttendance(
        query: query,
        request: RecordTransportAttendanceRequest(
          id: target.id,
          studentName: target.studentName,
          stopName: target.stopName,
          routeName: target.routeName,
          scheduledTime: target.scheduledTime,
          actualTime: target.actualTime,
          status: TransportAttendanceStatus.picked,
          parentNotified: target.parentNotified,
          shift: target.shift,
        ),
      );

      expect(updated.status, TransportAttendanceStatus.picked);

      final after = await repo.getAttendanceRecords(query: query);
      expect(after.items.length, before.items.length);
      expect(
        after.items.firstWhere((r) => r.id == target.id).status,
        TransportAttendanceStatus.picked,
      );
    });

    test('recordAttendance inserts a new record when id is null', () async {
      final repo = MockTransportRepository();
      final before = await repo.getAttendanceRecords(query: query);

      final created = await repo.recordAttendance(
        query: query,
        request: const RecordTransportAttendanceRequest(
          studentName: 'New Rider',
          stopName: 'Stop X',
          routeName: 'Route 12 — North',
          status: TransportAttendanceStatus.absent,
        ),
      );

      expect(created.studentName, 'New Rider');
      final after = await repo.getAttendanceRecords(query: query);
      expect(after.items.length, before.items.length + 1);
    });

    test('assignStudentTransport carries real SIS identity through', () async {
      final repo = MockTransportRepository();

      final assigned = await repo.assignStudentTransport(
        query: query,
        request: const AssignStudentTransportRequest(
          allocationId: 'alloc_5',
          routeId: 'route_12',
          pickupStop: 'Lake View Colony',
          dropStop: 'Akshara Main Gate',
          studentName: 'Kavya Iyer',
          admissionNumber: 'ADM-2026-0145',
          sisStudentId: 'SIS-STU-10425',
          classLabel: '6',
        ),
      );

      expect(assigned.studentName, 'Kavya Iyer');
      expect(assigned.sisStudentId, 'SIS-STU-10425');
      expect(assigned.admissionNumber, 'ADM-2026-0145');
    });

    test('notifyRouteDelay returns route + affected cohort count', () async {
      final repo = MockTransportRepository();

      final result = await repo.notifyRouteDelay(
        query: query,
        request: const NotifyRouteDelayRequest(
          routeId: 'route_12',
          message: 'Bus running 15 min late',
        ),
      );

      expect(result.routeName, 'Route 12 — North');
      expect(result.recipientCount, greaterThanOrEqualTo(2));
    });

    test('notifyRouteDelay rejects empty message', () async {
      final repo = MockTransportRepository();
      expect(
        () => repo.notifyRouteDelay(
          query: query,
          request: const NotifyRouteDelayRequest(
            routeId: 'route_12',
            message: '   ',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Transport mock writes', () {
    const query = RepositoryQuery.demo;

    test('createRoute inserts draft route', () async {
      final repo = MockTransportRepository();
      final before = await repo.getRoutes(query: query);

      final route = await repo.createRoute(
        query: query,
        request: const CreateTransportRouteRequest(name: 'QA Route North'),
      );

      final after = await repo.getRoutes(query: query);
      expect(after.total, greaterThan(before.total));
      expect(route.status, TransportRouteStatus.draft);
      expect(route.name, 'QA Route North');
    });

    test('activateRoute changes draft to active', () async {
      final repo = MockTransportRepository();
      final created = await repo.createRoute(
        query: query,
        request: const CreateTransportRouteRequest(name: 'QA Activate Route'),
      );

      final activated = await repo.activateRoute(
        query: query,
        request: ActivateTransportRouteRequest(routeId: created.id),
      );

      expect(activated.status, TransportRouteStatus.active);
    });
  });

  group('Transport RBAC mutations', () {
    test('assignStudentTransport fails without manageTransport', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(assignStudentTransportProvider.notifier).execute(
            const AssignStudentTransportRequest(
              allocationId: 'alloc_5',
              routeId: 'route_12',
              pickupStop: 'Lake View Colony',
              dropStop: 'Akshara Main Gate',
            ),
          );

      expect(container.read(assignStudentTransportProvider).hasError, isTrue);
    });

    test('createTransportRoute fails without manageTransport', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createTransportRouteProvider.notifier).execute(
            const CreateTransportRouteRequest(name: 'Denied'),
          );

      expect(container.read(createTransportRouteProvider).hasError, isTrue);
    });

    test('activateTransportRoute fails without manageTransport', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(activateTransportRouteProvider.notifier).execute(
            const ActivateTransportRouteRequest(routeId: 'route_1'),
          );

      expect(container.read(activateTransportRouteProvider).hasError, isTrue);
    });

    test('recordAttendance fails without manageTransport', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(recordTransportAttendanceProvider.notifier).execute(
            const RecordTransportAttendanceRequest(
              studentName: 'Denied Rider',
              status: TransportAttendanceStatus.picked,
            ),
          );

      expect(
        container.read(recordTransportAttendanceProvider).hasError,
        isTrue,
      );
    });

    test('notifyRouteDelay fails without manageTransport', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(notifyRouteDelayProvider.notifier).execute(
            const NotifyRouteDelayRequest(
              routeId: 'route_12',
              message: 'Late',
            ),
          );

      expect(container.read(notifyRouteDelayProvider).hasError, isTrue);
    });
  });
}
