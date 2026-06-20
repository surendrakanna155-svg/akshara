import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/school_config/school_configuration_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/workspace/workspace.dart';
import 'package:akshara_erp/core/workspace/workspace_providers.dart';
import 'package:akshara_erp/features/admin/admin_navigation_provider.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final caps = SchoolConfiguration.demoDefault().capabilities;

  ProviderContainer containerFor(List<ErpRole> roles, {WorkspaceId? active}) {
    final c = ProviderContainer(
      overrides: [
        schoolCapabilitiesProvider.overrideWithValue(caps),
        userPermissionsProvider
            .overrideWithValue(UserPermissions.forRoles(roles)),
        if (active != null)
          activeWorkspaceIdProvider.overrideWith((ref) => active),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('workspaceScopedNavDestinationsProvider', () {
    test('finance admin hub is scoped to Finance workspace modules', () {
      final c = containerFor([ErpRole.financeAdmin]);
      final routes = c
          .read(workspaceScopedNavDestinationsProvider)
          .map((d) => d.route)
          .toSet();
      expect(routes, contains(RouteNames.admin)); // hub landing
      expect(routes, contains(RouteNames.financeDashboard));
      // Finance workspace excludes other modules even though permission-filter
      // would otherwise show the admin hub root only.
      expect(routes, isNot(contains(RouteNames.sisDashboard)));
    });

    test('multi-hat user: active workspace scopes the grid', () {
      // Surendra: Inventory (primary) + Teacher. Active = inventory.
      final c = containerFor(
        [ErpRole.inventoryManager, ErpRole.teacher],
        active: WorkspaceId.inventory,
      );
      final routes = c
          .read(workspaceScopedNavDestinationsProvider)
          .map((d) => d.route)
          .toSet();
      expect(routes, contains(RouteNames.inventoryDashboard));
      // Teaching has no admin modules, and other admin modules are out of scope.
      expect(routes, isNot(contains(RouteNames.financeDashboard)));
    });

    test('user has both workspaces available', () {
      final c = containerFor([ErpRole.inventoryManager, ErpRole.teacher]);
      final ws = c.read(userWorkspacesProvider).map((w) => w.id).toSet();
      expect(ws, {WorkspaceId.inventory, WorkspaceId.teaching});
      expect(c.read(hasMultipleWorkspacesProvider), isTrue);
    });

    test('single-role user is not multi-workspace', () {
      final c = containerFor([ErpRole.financeAdmin]);
      expect(c.read(hasMultipleWorkspacesProvider), isFalse);
    });
  });
}
