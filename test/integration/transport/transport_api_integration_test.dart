import 'package:akshara_erp/core/repositories/api/transport/api_transport_repository.dart';
import 'package:akshara_erp/core/repositories/api/transport/remote/transport_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/transport/remote/transport_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_transport_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/transport/transport_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/transport/transport_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = TransportFixtureBuilder();

void main() {
  group('Transport API integration', () {
    late MockTransportRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUp(() async {
      mockRepo = MockTransportRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final routes = await mockRepo.getRoutes(query: kQuery);
      final vehicles = await mockRepo.getVehicles(query: kQuery);
      final drivers = await mockRepo.getDrivers(query: kQuery);
      final allocations = await mockRepo.getAllocations(query: kQuery);
      final attendance = await mockRepo.getAttendanceRecords(query: kQuery);
      final tracking = await mockRepo.getTrackingPlaceholder(query: kQuery);
      final reports = await mockRepo.getReports(query: kQuery);
      final settings = await mockRepo.getSettings(query: kQuery);
      final occupancy = await mockRepo.getOccupancyMetrics(query: kQuery);

      responseForPath = (path) => switch (path) {
            TransportApiPaths.dashboard =>
              _fixtures.dashboardEnvelope(dashboard),
            TransportApiPaths.routes => _fixtures.routesEnvelope(routes.items),
            TransportApiPaths.vehicles => _fixtures.vehiclesEnvelope(vehicles),
            TransportApiPaths.drivers => _fixtures.driversEnvelope(drivers),
            TransportApiPaths.allocations =>
              _fixtures.allocationsEnvelope(allocations),
            TransportApiPaths.attendance =>
              _fixtures.attendanceEnvelope(attendance),
            TransportApiPaths.tracking => _fixtures.trackingEnvelope(tracking),
            TransportApiPaths.reports => _fixtures.reportsEnvelope(reports),
            TransportApiPaths.settings => _fixtures.settingsEnvelope(settings),
            TransportApiPaths.occupancyMetrics =>
              _fixtures.occupancyMetricsEnvelope(occupancy),
            _ => const {'data': {}},
          };
    });

    test('remote datasource fetches all Transport read endpoints', () async {
      final remote = TransportRemoteDataSource(
        createFakeDio((options) => responseForPath(options.path)),
      );

      expect((await remote.fetchDashboard(query: kQuery)).raw['kpis'], isNotNull);
      expect((await remote.fetchRoutes(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchVehicles(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchDrivers(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchAllocations(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchAttendanceRecords(query: kQuery)).items, isNotEmpty);
      expect(
        (await remote.fetchTrackingPlaceholder(query: kQuery)).raw['vehicles'],
        isNotNull,
      );
      expect((await remote.fetchReports(query: kQuery)).raw['catalog'], isNotNull);
      expect((await remote.fetchSettings(query: kQuery)).raw['sections'], isNotNull);
      expect(
        (await remote.fetchOccupancyMetrics(query: kQuery)).raw['totalCapacity'],
        isNotNull,
      );
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiTransportRepository(
        remote: TransportRemoteDataSource(
          createFakeDio((options) => responseForPath(options.path)),
        ),
      );

      final mockData = await mockRepo.getDashboard(query: kQuery);
      final apiData = await repository.getDashboard(query: kQuery);

      expect(apiData.kpis.length, mockData.kpis.length);
      expect(apiData.aiInsight, mockData.aiInsight);
    });

    test('provider chain loads dashboard in api mode', () async {
      await initProviderTestPrefs();
      final container = createProviderTestContainer(
        apiTransportDio: createFakeDio(
          (options) => responseForPath(options.path),
        ),
        transportApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data = await container.read(transportDashboardFutureProvider.future);
      expect(data.kpis, isNotEmpty);
    });
  });
}
