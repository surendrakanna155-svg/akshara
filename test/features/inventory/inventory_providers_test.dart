import 'package:akshara_erp/features/inventory/inventory_models.dart';
import 'package:akshara_erp/features/inventory/inventory_providers.dart';
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

  group('Inventory providers', () {
    test('inventoryDashboardProvider returns dashboard data', () async {      await container.read(inventoryDashboardFutureProvider.future);

      final data = container.read(inventoryDashboardProvider);

      expect(data, isNotNull);
      expect(data!.kpis, hasLength(6));
      expect(data.recentActivity, isNotEmpty);
      expect(data.integrationLinks, hasLength(4));
    });

    test('inventoryDashboardProvider returns null when loading', () async {
      container = createProviderTestContainer(
        overrides: [
          inventoryDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );

      expect(container.read(inventoryDashboardProvider), isNull);
    });

    test('inventoryAssetsProvider returns assets', () async {      await container.read(inventoryAssetsFutureProvider.future);

      final assets = container.read(inventoryAssetsProvider);

      expect(assets, isNotNull);
      expect(assets!, hasLength(4));
    });

    test('inventoryFilteredAssetsProvider filters allocated assets', () async {
      container = createProviderTestContainer(
        overrides: [
          inventoryAssetsFilterProvider.overrideWith((ref) => 2),
        ],
      );

      final filtered = container.read(inventoryFilteredAssetsProvider);
      expect(
        filtered.every((a) => a.status == InventoryAssetStatus.allocated),
        isTrue,
      );
    });

    test('inventoryCategoriesProvider returns categories', () async {      await container.read(inventoryCategoriesFutureProvider.future);

      final categories = container.read(inventoryCategoriesProvider);

      expect(categories, isNotNull);
      expect(categories!, hasLength(4));
    });

    test('inventoryAllocationsProvider returns cross-module allocations', () async {      await container.read(inventoryAllocationsFutureProvider.future);

      final allocations = container.read(inventoryAllocationsProvider);

      expect(allocations, isNotNull);
      expect(allocations!.first.hrEmployeeId, startsWith('HR-EMP-'));
    });

    test('inventoryFilteredAllocationsProvider filters active', () async {
      container = createProviderTestContainer(
        overrides: [
          inventoryAllocationFilterProvider.overrideWith((ref) => 1),
        ],
      );

      final filtered = container.read(inventoryFilteredAllocationsProvider);
      expect(
        filtered.every((a) => a.status == InventoryAllocationStatus.active),
        isTrue,
      );
    });

    test('inventoryMaintenanceProvider returns maintenance records', () async {      await container.read(inventoryMaintenanceFutureProvider.future);

      final records = container.read(inventoryMaintenanceProvider);

      expect(records, isNotNull);
      expect(records!, hasLength(4));
    });

    test('inventoryProcurementProvider returns procurement orders', () async {      await container.read(inventoryProcurementFutureProvider.future);

      final orders = container.read(inventoryProcurementProvider);

      expect(orders, isNotNull);
      expect(orders!.first.financePoId, isNotEmpty);
    });

    test('inventoryVendorsProvider returns vendors', () async {      await container.read(inventoryVendorsFutureProvider.future);

      final vendors = container.read(inventoryVendorsProvider);

      expect(vendors, isNotNull);
      expect(vendors!, hasLength(4));
    });

    test('inventoryFilteredVendorsProvider filters active vendors', () async {
      container = createProviderTestContainer(
        overrides: [
          inventoryVendorsFilterProvider.overrideWith((ref) => 1),
        ],
      );

      final filtered = container.read(inventoryFilteredVendorsProvider);
      expect(
        filtered.every((v) => v.status == InventoryVendorStatus.active),
        isTrue,
      );
    });

    test('inventoryReportsProvider returns reports data', () async {      await container.read(inventoryReportsFutureProvider.future);

      final data = container.read(inventoryReportsProvider);

      expect(data, isNotNull);
      expect(data!.catalog, hasLength(6));
    });
  });
}
