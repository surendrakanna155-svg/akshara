import 'package:akshara_erp/core/repositories/api/inventory/api_inventory_repository.dart';
import 'package:akshara_erp/core/repositories/api/inventory/remote/inventory_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/inventory/remote/inventory_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/inventory/inventory_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/inventory/inventory_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = InventoryFixtureBuilder();

void main() {
  group('Inventory API integration', () {
    late MockInventoryRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUp(() async {
      mockRepo = MockInventoryRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final assets = await mockRepo.getAssets(query: kQuery);
      final categories = await mockRepo.getCategories(query: kQuery);
      final allocations = await mockRepo.getAllocations(query: kQuery);
      final maintenance = await mockRepo.getMaintenanceRecords(query: kQuery);
      final procurement = await mockRepo.getProcurementOrders(query: kQuery);
      final vendors = await mockRepo.getVendors(query: kQuery);
      final reports = await mockRepo.getReports(query: kQuery);

      responseForPath = (path) => switch (path) {
            InventoryApiPaths.dashboard =>
              _fixtures.dashboardEnvelope(dashboard),
            InventoryApiPaths.assets => _fixtures.assetsEnvelope(assets.items),
            InventoryApiPaths.categories =>
              _fixtures.categoriesEnvelope(categories.items),
            InventoryApiPaths.allocations =>
              _fixtures.allocationsEnvelope(allocations.items),
            InventoryApiPaths.maintenance =>
              _fixtures.maintenanceEnvelope(maintenance.items),
            InventoryApiPaths.procurement =>
              _fixtures.procurementEnvelope(procurement.items),
            InventoryApiPaths.vendors => _fixtures.vendorsEnvelope(vendors.items),
            InventoryApiPaths.reports => _fixtures.reportsEnvelope(reports),
            _ => const {'data': {}},
          };
    });

    test('remote datasource fetches all Inventory read endpoints', () async {
      final remote = InventoryRemoteDataSource(
        createFakeDio((options) => responseForPath(options.path)),
      );

      expect((await remote.fetchDashboard(query: kQuery)).raw['kpis'], isNotNull);
      expect((await remote.fetchAssets(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchCategories(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchAllocations(query: kQuery)).items, isNotEmpty);
      expect(
        (await remote.fetchMaintenanceRecords(query: kQuery)).items,
        isNotEmpty,
      );
      expect(
        (await remote.fetchProcurementOrders(query: kQuery)).items,
        isNotEmpty,
      );
      expect((await remote.fetchVendors(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchReports(query: kQuery)).raw['catalog'], isNotNull);
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiInventoryRepository(
        remote: InventoryRemoteDataSource(
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
        apiInventoryDio: createFakeDio((options) => responseForPath(options.path)),
        inventoryApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data = await container.read(inventoryDashboardFutureProvider.future);
      expect(data.kpis, isNotEmpty);
    });
  });
}
