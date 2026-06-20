import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/workspace/workspace.dart';
import 'package:akshara_erp/features/admin/models/admin_nav_models.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('workspacesForRoles', () {
    test('a specialist role maps to its single workspace', () {
      final ws = workspacesForRoles([ErpRole.financeAdmin]);
      expect(ws.map((w) => w.id), [WorkspaceId.finance]);
      expect(ws.single.shell, UserRole.staff);
    });

    test('leadership maps to the School Administration workspace', () {
      for (final role in [
        ErpRole.superAdmin,
        ErpRole.schoolAdmin,
        ErpRole.principal,
        ErpRole.vicePrincipal,
        ErpRole.management,
      ]) {
        expect(
          workspacesForRoles([role]).map((w) => w.id),
          [WorkspaceId.schoolAdministration],
          reason: '$role',
        );
      }
    });

    test('multi-role user gets multiple workspaces (Teacher + Inventory)', () {
      final ws = workspacesForRoles([ErpRole.teacher, ErpRole.inventoryManager]);
      expect(ws.map((w) => w.id),
          [WorkspaceId.teaching, WorkspaceId.inventory]);
      // Different shells — drives the cross-shell switcher.
      expect(ws[0].shell, UserRole.teacher);
      expect(ws[1].shell, UserRole.staff);
    });

    test('order follows role order (primary first)', () {
      final ws = workspacesForRoles([ErpRole.inventoryManager, ErpRole.teacher]);
      expect(ws.map((w) => w.id),
          [WorkspaceId.inventory, WorkspaceId.teaching]);
    });

    test('roles sharing a workspace are deduped', () {
      // inventoryManager + storekeeper both map to the Inventory workspace.
      final ws = workspacesForRoles([ErpRole.inventoryManager, ErpRole.storekeeper]);
      expect(ws.map((w) => w.id), [WorkspaceId.inventory]);
    });

    test('unknown/empty roles yield no workspaces', () {
      expect(workspacesForRoles(const <ErpRole>[]), isEmpty);
    });
  });

  group('workspace catalog', () {
    test('every role maps to catalogued workspaces', () {
      for (final role in ErpRole.values) {
        for (final id in kRoleWorkspaces[role] ?? const <WorkspaceId>[]) {
          expect(kWorkspaceCatalog.containsKey(id), isTrue, reason: '$role -> $id');
        }
      }
    });

    test('specialist workspaces are scoped to their own module only', () {
      expect(kWorkspaceCatalog[WorkspaceId.finance]!.modules,
          {AdminModule.finance});
      expect(kWorkspaceCatalog[WorkspaceId.inventory]!.modules,
          {AdminModule.inventory});
    });

    test('School Administration excludes non-school verticals', () {
      final modules = kWorkspaceCatalog[WorkspaceId.schoolAdministration]!.modules;
      expect(modules.contains(AdminModule.salon), isFalse);
      expect(modules.contains(AdminModule.restaurant), isFalse);
      expect(modules.contains(AdminModule.healthcare), isFalse);
      expect(modules.contains(AdminModule.accommodation), isFalse);
      expect(modules.contains(AdminModule.whiteLabel), isFalse);
      expect(modules.contains(AdminModule.platformOperations), isFalse);
      // But includes the core school modules + multi-school management:
      expect(modules.contains(AdminModule.finance), isTrue);
      expect(modules.contains(AdminModule.sis), isTrue);
      expect(modules.contains(AdminModule.controlCenter), isTrue);
    });
  });
}
