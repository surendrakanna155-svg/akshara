import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/repositories/api/transport/api_transport_repository.dart';
import 'package:akshara_erp/core/repositories/api/transport/dto/transport_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/transport/mapper/transport_mapper.dart';
import 'package:akshara_erp/core/repositories/api/transport/remote/transport_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/transport_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_transport_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_transport_write_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/transport/transport_models.dart';
import 'package:akshara_erp/features/transport/transport_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'transport_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = TransportFixtureBuilder();
const _mapper = TransportMapper();

void main() {
  group('Transport repository contract', () {
    late MockTransportRepository mockRepo;
    late ApiTransportRepository apiRepo;

    setUp(() {
      mockRepo = MockTransportRepository();
      apiRepo = ApiTransportRepository(
        remote: TransportRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement TransportRepository', () {
      expect(mockRepo, isA<TransportRepository>());
      expect(apiRepo, isA<TransportRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        TransportDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );
      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
    });

    test('getRoutes DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getRoutes(query: kQuery);
      final mapped = [
        for (final item
            in TransportRoutesResponseDto.fromJson(
              _fixtures.routesEnvelope(mockData.items),
            ).items)
          _mapper.toRoute(item),
      ];
      expect(mapped.length, mockData.items.length);
      expect(mapped.first.name, mockData.items.first.name);
    });

    test('getVehicles DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getVehicles(query: kQuery);
      final mapped = [
        for (final item
            in TransportVehiclesResponseDto.fromJson(
              _fixtures.vehiclesEnvelope(mockData.items),
            ).items)
          _mapper.toVehicle(item),
      ];
      expect(mapped.length, mockData.items.length);
    });

    test('getDrivers DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDrivers(query: kQuery);
      final mapped = [
        for (final item
            in TransportDriversResponseDto.fromJson(
              _fixtures.driversEnvelope(mockData.items),
            ).items)
          _mapper.toDriver(item),
      ];
      expect(mapped.length, mockData.items.length);
    });

    test('getAllocations DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAllocations(query: kQuery);
      final mapped = [
        for (final item
            in TransportAllocationsResponseDto.fromJson(
              _fixtures.allocationsEnvelope(mockData.items),
            ).items)
          _mapper.toAllocation(item),
      ];
      expect(mapped.length, mockData.items.length);
    });

    test('getAttendanceRecords DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAttendanceRecords(query: kQuery);
      final mapped = [
        for (final item
            in TransportAttendanceResponseDto.fromJson(
              _fixtures.attendanceEnvelope(mockData.items),
            ).items)
          _mapper.toAttendanceRecord(item),
      ];
      expect(mapped.length, mockData.items.length);
    });

    test('getTrackingPlaceholder DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getTrackingPlaceholder(query: kQuery);
      final mapped = _mapper.toTrackingPlaceholder(
        TransportTrackingDto.fromJson(_fixtures.trackingEnvelope(mockData)),
      );
      expect(mapped.vehicles.length, mockData.vehicles.length);
    });

    test('getReports DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getReports(query: kQuery);
      final mapped = _mapper.toReports(
        TransportReportsDto.fromJson(_fixtures.reportsEnvelope(mockData)),
      );
      expect(mapped.catalog.length, mockData.catalog.length);
    });

    test('getSettings DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSettings(query: kQuery);
      final mapped = _mapper.toSettings(
        TransportSettingsDto.fromJson(_fixtures.settingsEnvelope(mockData)),
      );
      expect(mapped.sections.length, mockData.sections.length);
    });

    test('getOccupancyMetrics DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getOccupancyMetrics(query: kQuery);
      final mapped = _mapper.toOccupancyMetrics(
        OccupancyMetricsDto.fromJson(
          _fixtures.occupancyMetricsEnvelope(mockData),
        ),
      );
      expect(mapped.totalCapacity, mockData.totalCapacity);
    });

    // ── TRN-3/5/8/9 new-method DTO round-trips ──────────────────────────────
    test('getRouteRoster DTO mapping round-trips', () async {
      final mockData = await mockRepo.getRouteRoster(
        query: kQuery,
        routeId: 'route_12',
      );
      final mapped = _mapper.toRoster(
        TransportRosterDto.fromJson(_fixtures.rosterEnvelope(mockData)),
      );
      expect(mapped.routeId, mockData.routeId);
      expect(mapped.stops.length, mockData.stops.length);
      expect(mapped.studentCount, mockData.studentCount);
    });

    test('bulk allocation result DTO round-trips', () {
      const result = BulkAllocationResult(
        routeId: 'route_12',
        assigned: ['SIS-1', 'SIS-2'],
        skipped: [SkippedAllocation(studentId: 'SIS-3', reason: 'empty')],
        capacityOverridden: true,
      );
      final mapped = _mapper.toBulkAllocationResult(
        BulkAllocationResultDto.fromJson(_fixtures.bulkAllocationResult(result)),
      );
      expect(mapped.assignedCount, 2);
      expect(mapped.skipped.single.reason, 'empty');
      expect(mapped.capacityOverridden, isTrue);
    });

    test('document-expiry reminder DTO round-trips', () {
      final mapped = _mapper.toDocumentExpiryReminderCount(
        TransportDocumentExpiryReminderDto.fromJson(
          _fixtures.documentExpiryReminder(4),
        ),
      );
      expect(mapped, 4);
    });

    test('transport demand DTO round-trips (idempotent flag)', () {
      const result = TransportDemandResult(
        id: 'demand_1',
        sisStudentId: 'SIS-1',
        routeId: 'route_12',
        feeStructureId: 'fee_1',
        academicYear: '2026-27',
        term: 'annual',
        invoiceId: 'inv_1',
        accountId: 'acct_1',
        idempotent: true,
      );
      final mapped = _mapper.toDemandResult(
        TransportDemandResultDto.fromJson(_fixtures.demandResult(result)),
      );
      expect(mapped.invoiceId, 'inv_1');
      expect(mapped.idempotent, isTrue);
    });
  });

  group('Transport mock new-write parity', () {
    setUp(() => MockTransportWriteStore.instance.reset());

    test('vehicle create/update/delete + duplicate + in-use guards', () async {
      final repo = MockTransportRepository();
      final created = await repo.createVehicle(
        query: kQuery,
        request: const CreateTransportVehicleRequest(
          registration: 'TS 01 XX 0001',
          capacity: 30,
          insuranceExpiry: '2026-12-31',
        ),
      );
      expect(created.capacity, 30);
      expect(created.insuranceExpiry, '2026-12-31');

      // Duplicate registration → typed DUPLICATE_REGISTRATION failure.
      await expectLater(
        () => repo.createVehicle(
          query: kQuery,
          request: const CreateTransportVehicleRequest(
            registration: 'ts 01 xx 0001',
          ),
        ),
        throwsA(isA<ApiFailureException>().having(
          (e) => e.failure.code,
          'code',
          'DUPLICATE_REGISTRATION',
        )),
      );

      final updated = await repo.updateVehicle(
        query: kQuery,
        request: UpdateTransportVehicleRequest(id: created.id, capacity: 44),
      );
      expect(updated.capacity, 44);

      await repo.deleteVehicle(
        query: kQuery,
        request: DeleteTransportVehicleRequest(id: created.id),
      );
      final vehicles = await repo.getVehicles(query: kQuery);
      expect(vehicles.items.any((v) => v.id == created.id), isFalse);

      // Deleting a vehicle assigned to an active route is blocked.
      final active = vehicles.items.firstWhere((v) => v.busNumber == 'BUS-07');
      await expectLater(
        () => repo.deleteVehicle(
          query: kQuery,
          request: DeleteTransportVehicleRequest(id: active.id),
        ),
        throwsA(isA<ApiFailureException>().having(
          (e) => e.failure.code,
          'code',
          'VEHICLE_IN_USE',
        )),
      );
    });

    test('driver create/update/delete + duplicate licence guard', () async {
      final repo = MockTransportRepository();
      final created = await repo.createDriver(
        query: kQuery,
        request: const CreateTransportDriverRequest(
          name: 'New Driver',
          licenseNumber: 'DL-NEW-1',
          licenseExpiry: '2027-06-30',
        ),
      );
      expect(created.name, 'New Driver');

      await expectLater(
        () => repo.createDriver(
          query: kQuery,
          request: const CreateTransportDriverRequest(
            name: 'Dup',
            licenseNumber: 'dl-new-1',
          ),
        ),
        throwsA(isA<ApiFailureException>().having(
          (e) => e.failure.code,
          'code',
          'DUPLICATE_LICENSE',
        )),
      );

      final updated = await repo.updateDriver(
        query: kQuery,
        request: UpdateTransportDriverRequest(id: created.id, phone: '+91 90000'),
      );
      expect(updated.phone, '+91 90000');

      await repo.deleteDriver(
        query: kQuery,
        request: DeleteTransportDriverRequest(id: created.id),
      );
      final drivers = await repo.getDrivers(query: kQuery);
      expect(drivers.items.any((d) => d.id == created.id), isFalse);
    });

    test('stop editor add/reorder/edit/remove resequences', () async {
      final repo = MockTransportRepository();
      var route = await repo.addStop(
        query: kQuery,
        request: const AddTransportStopRequest(
          routeId: 'route_12',
          name: 'New Stop',
          pickupTime: '7:50 AM',
        ),
      );
      final added = route.stops.last;
      expect(added.name, 'New Stop');
      expect(added.sequence, route.stops.length);

      route = await repo.updateStop(
        query: kQuery,
        request: UpdateTransportStopRequest(
          routeId: 'route_12',
          stopId: added.id,
          name: 'Renamed Stop',
        ),
      );
      expect(route.stops.firstWhere((s) => s.id == added.id).name,
          'Renamed Stop');

      final order = [
        for (final s in route.stops) s.id,
      ].reversed.toList();
      route = await repo.reorderStops(
        query: kQuery,
        request: ReorderTransportStopsRequest(
          routeId: 'route_12',
          stopOrder: order,
        ),
      );
      expect(route.stops.first.sequence, 1);
      expect(route.stops.first.id, order.first);

      route = await repo.removeStop(
        query: kQuery,
        request: RemoveTransportStopRequest(
          routeId: 'route_12',
          stopId: added.id,
        ),
      );
      expect(route.stops.any((s) => s.id == added.id), isFalse);
    });

    test('bulkAllocateTransport returns assigned + skipped', () async {
      final repo = MockTransportRepository();
      final result = await repo.bulkAllocateTransport(
        query: kQuery,
        request: const BulkAllocateTransportRequest(
          routeId: 'route_12',
          pickupStop: 'Lake View Colony',
          dropStop: 'Akshara Main Gate',
          sisStudentIds: ['SIS-STU-10425'],
        ),
      );
      expect(result.routeId, 'route_12');
      expect(result.assigned, contains('SIS-STU-10425'));
    });

    test('raiseTransportDemand is idempotent on re-raise', () async {
      final repo = MockTransportRepository();
      const req = RaiseTransportDemandRequest(
        sisStudentId: 'SIS-STU-10430',
        routeId: 'route_12',
        feeStructureId: 'fee_transport',
        academicYear: '2026-27',
      );
      final first = await repo.raiseTransportDemand(query: kQuery, request: req);
      expect(first.idempotent, isFalse);
      final second = await repo.raiseTransportDemand(query: kQuery, request: req);
      expect(second.idempotent, isTrue);
      expect(second.invoiceId, first.invoiceId);
    });

    test('sendTransportDocumentExpiryReminder counts ISO-dated docs', () async {
      final repo = MockTransportRepository();
      final soon = DateTime.now().add(const Duration(days: 10));
      final iso = '${soon.year.toString().padLeft(4, '0')}-'
          '${soon.month.toString().padLeft(2, '0')}-'
          '${soon.day.toString().padLeft(2, '0')}';
      await repo.createVehicle(
        query: kQuery,
        request: CreateTransportVehicleRequest(
          registration: 'TS 02 YY 0002',
          insuranceExpiry: iso,
        ),
      );
      final count = await repo.sendTransportDocumentExpiryReminder(
        query: kQuery,
        request: const SendTransportDocumentExpiryReminderRequest(),
      );
      expect(count, greaterThanOrEqualTo(1));
    });
  });
}
