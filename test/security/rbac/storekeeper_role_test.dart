import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Storekeeper RBAC — M-D6', () {
    late UserPermissions storekeeper;
    late UserPermissions principal;

    setUp(() {
      storekeeper = UserPermissions.forRole(ErpRole.storekeeper);
      principal = UserPermissions.forRole(ErpRole.principal);
    });

    test('storekeeper can create PO but not approve', () {
      expect(storekeeper.has(Permission.createInventoryPo), isTrue);
      expect(storekeeper.has(Permission.approvePurchaseOrder), isFalse);
      expect(storekeeper.has(Permission.manageInventory), isFalse);
      expect(storekeeper.has(Permission.manageProcurementWorkflow), isFalse);
      expect(storekeeper.has(Permission.manageAssetLifecycle), isFalse);
    });

    test('principal can approve purchase orders', () {
      expect(principal.has(Permission.approvePurchaseOrder), isTrue);
    });

    test('inventory manager retains full inventory permissions', () {
      final manager = UserPermissions.forRole(ErpRole.inventoryManager);
      expect(manager.has(Permission.createInventoryPo), isTrue);
      expect(manager.has(Permission.approvePurchaseOrder), isTrue);
      expect(manager.has(Permission.manageInventory), isTrue);
    });
  });
}
