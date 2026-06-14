import 'package:akshara_erp/core/repositories/mock/mock_inventory_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/inventory/inventory_requests.dart';
import 'package:akshara_erp/features/inventory/inventory_mutations_provider.dart';
import 'package:akshara_erp/features/inventory/intelligence/inventory_intelligence_models.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  group('Inventory mock writes', () {
    const query = RepositoryQuery.demo;

    test('createProcurementOrder inserts draft PO', () async {
      final repo = MockInventoryRepository();
      final before = await repo.getProcurementOrders(query: query);

      final order = await repo.createProcurementOrder(
        query: query,
        request: const CreateInventoryProcurementOrderRequest(
          vendorName: 'QA Vendor',
          items: 'Chairs x10',
          totalAmount: '₹50,000',
          requestedBy: 'Facilities',
        ),
      );

      final after = await repo.getProcurementOrders(query: query);
      expect(after.total, greaterThan(before.total));
      expect(order.poNumber, startsWith('PO-2026-'));
    });

    test('recordProcurementReceiveHandoff marks ordered PO received', () async {
      final repo = MockInventoryRepository();
      final ordered = await repo.getProcurementOrders(query: query);
      final target = ordered.items.firstWhere((order) => order.id == 'po_1');
      expect(target.status.name, 'ordered');

      final updated = await repo.recordProcurementReceiveHandoff(
        query: query,
        orderId: 'po_1',
      );
      expect(updated.status.name, 'received');
    });
  });

  group('Inventory RBAC mutations', () {
    test('recordAssetLifecycleEvent fails without manageInventory', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(recordAssetLifecycleEventProvider.notifier).execute(
            const RecordAssetLifecycleEventRequest(
              assetId: 'asset_1',
              eventType: AssetLifecycleEventType.distribution,
              notes: 'Test',
            ),
          );

      expect(container.read(recordAssetLifecycleEventProvider).hasError, isTrue);
    });
  });

  group('Inventory lifecycle mock writes', () {
    test('recordAssetLifecycleEvent persists event', () async {
      final repo = MockInventoryRepository();
      const query = RepositoryQuery.demo;

      final before = await repo.getAssetLifecycle(query: query);
      await repo.recordAssetLifecycleEvent(
        query: query,
        request: const RecordAssetLifecycleEventRequest(
          assetId: 'asset_9',
          assetTag: 'INV-QA-001',
          eventType: AssetLifecycleEventType.purchase,
          notes: 'QA purchase event',
        ),
      );
      final after = await repo.getAssetLifecycle(query: query);

      expect(after.recentEvents.length, greaterThan(before.recentEvents.length));
    });
  });
}
