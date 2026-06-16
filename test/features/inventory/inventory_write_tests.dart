import 'package:akshara_erp/core/repositories/mock/mock_inventory_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/features/inventory/inventory_requests.dart';
import 'package:akshara_erp/features/inventory/inventory_mutations_provider.dart';
import 'package:akshara_erp/features/inventory/inventory_providers.dart';
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
          financePoId: 'po_if_linked',
          poNumber: 'PO-2026-TEST',
        ),
      );

      final after = await repo.getProcurementOrders(query: query);
      expect(after.total, greaterThan(before.total));
      expect(order.poNumber, 'PO-2026-TEST');
      expect(order.financePoId, 'po_if_linked');
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
      expect(updated.approvalHistory.last.action, 'received');
    });

    test('approveProcurementOrder marks draft PO ordered', () async {
      final repo = MockInventoryRepository();
      final draft = await repo.getProcurementOrders(query: query);
      final target = draft.items.firstWhere((order) => order.id == 'po_4');
      expect(target.status.name, 'draft');

      final approved = await repo.approveProcurementOrder(
        query: query,
        orderId: 'po_4',
      );
      expect(approved.status.name, 'ordered');
      expect(approved.approvalHistory.last.action, 'approved');
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

      expect(
          container.read(recordAssetLifecycleEventProvider).hasError, isTrue);
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

      expect(
          after.recentEvents.length, greaterThan(before.recentEvents.length));
    });
  });

  group('Inventory procurement handoff chain', () {
    test('approve + receive handoff updates finance and inventory state',
        () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final before =
          await container.read(inventoryProcurementFutureProvider.future);
      final draft = before.items.firstWhere((order) => order.id == 'po_4');
      expect(draft.status.name, 'draft');

      final approveResult = await container
          .read(approveProcurementHandoffProvider.notifier)
          .execute(draft);
      expect(approveResult.apCommitmentId, startsWith('ap_if_'));

      final inventoryRepo = container.read(inventoryRepositoryProvider);
      final afterApprove = await inventoryRepo.getProcurementOrders(
        query: RepositoryQuery.demo,
      );
      final ordered =
          afterApprove.items.firstWhere((order) => order.id == 'po_4');
      expect(ordered.status.name, 'ordered');

      final receiveResult = await container
          .read(receiveProcurementHandoffProvider.notifier)
          .execute(ordered);
      expect(receiveResult.grnId, startsWith('grn_if_'));

      final afterReceive = await inventoryRepo.getProcurementOrders(
        query: RepositoryQuery.demo,
      );
      final received =
          afterReceive.items.firstWhere((order) => order.id == 'po_4');
      expect(received.status.name, 'received');
      expect(received.approvalHistory.last.action, 'received');
    });

    test('create + approve + receive handoff works for dynamic PO', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final created = await container
          .read(createProcurementOrderProvider.notifier)
          .execute(
            const CreateInventoryProcurementOrderRequest(
              vendorName: 'Dynamic Vendor',
              items: 'QA procurement items',
              totalAmount: '₹25,000',
              requestedBy: 'QA Procurement',
            ),
          );
      expect(created, isNotNull);
      expect(created!.financePoId, startsWith('po_if_'));

      final approveResult = await container
          .read(approveProcurementHandoffProvider.notifier)
          .execute(created);
      expect(approveResult.apCommitmentId, startsWith('ap_if_'));

      final inventoryRepo = container.read(inventoryRepositoryProvider);
      final afterApprove = await inventoryRepo.getProcurementOrders(
        query: RepositoryQuery.demo,
      );
      final ordered =
          afterApprove.items.firstWhere((order) => order.id == created.id);
      expect(ordered.status.name, 'ordered');

      final receiveResult = await container
          .read(receiveProcurementHandoffProvider.notifier)
          .execute(ordered);
      expect(receiveResult.grnId, startsWith('grn_if_'));

      final afterReceive = await inventoryRepo.getProcurementOrders(
        query: RepositoryQuery.demo,
      );
      final received =
          afterReceive.items.firstWhere((order) => order.id == created.id);
      expect(received.status.name, 'received');
    });
  });
}
