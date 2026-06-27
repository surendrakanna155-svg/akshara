import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/security/erp_role.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../evolution/evolution_models.dart';
import 'dynamic_widget_models.dart';

final dynamicWidgetQueryProvider = Provider<RepositoryQuery>(
  (ref) => ref.watch(repositoryQueryProvider),
);

/// Role used for layout resolution (query param override or session role).
final dynamicWidgetRoleProvider = StateProvider<String>((ref) {
  final role = ref.watch(rbacServiceProvider).role;
  return role?.name ?? ErpRole.principal.name;
});

final dynamicWidgetVerticalPackProvider = StateProvider<String>((ref) => 'school');

final widgetDataSourcesProvider = FutureProvider<List<WidgetDataSource>>((ref) async {
  return ref.read(evolutionRepositoryProvider).listWidgetDataSources(
        query: ref.watch(dynamicWidgetQueryProvider),
      );
});

final widgetLayoutVersionsProvider =
    FutureProvider.family<List<WidgetLayoutVersion>, ({String? role, String? pack})>(
  (ref, filters) async {
    return ref.read(evolutionRepositoryProvider).getWidgetLayoutVersions(
          query: ref.watch(dynamicWidgetQueryProvider),
          role: filters.role,
          verticalPack: filters.pack,
        );
  },
);

final roleDashboardLayoutProvider = FutureProvider.family<RoleDashboardLayout, String>(
  (ref, role) async {
    return ref.read(evolutionRepositoryProvider).getRoleDashboardLayout(
          query: ref.watch(dynamicWidgetQueryProvider),
          role: role,
        );
  },
);

final dynamicWidgetRegistryProvider = FutureProvider<List<WidgetDefinition>>((ref) async {
  return ref.read(evolutionRepositoryProvider).listWidgets(
        query: ref.watch(dynamicWidgetQueryProvider),
      );
});

final dynamicWidgetLiveDataProvider =
    FutureProvider.family<Map<String, WidgetLiveData>, String>(
  (ref, role) async {
    final layout = await ref.watch(roleDashboardLayoutProvider(role).future);
    // Apply the SAME RBAC predicate used at render so data for widgets the
    // user cannot view is never requested (no live data crosses the wire only
    // to be discarded). filterWidgetsByRbac already excludes invisible widgets.
    final rbac = ref.watch(rbacServiceProvider);
    final visibleIds = filterWidgetsByRbac(layout.widgets, rbac)
        .map((w) => w.id)
        .toList();
    if (visibleIds.isEmpty) return const {};
    return ref.read(evolutionRepositoryProvider).getWidgetData(
          query: ref.watch(dynamicWidgetQueryProvider),
          widgetIds: visibleIds,
        );
  },
);

Permission? _permissionFromSlug(String slug) {
  for (final permission in Permission.values) {
    if (permission.name == slug) return permission;
  }
  return null;
}

/// Filters widgets the current user may view based on widget-level permissions.
List<DynamicWidgetItem> filterWidgetsByRbac(
  List<DynamicWidgetItem> widgets,
  RbacService rbac,
) {
  return widgets.where((widget) {
    if (!widget.visible) return false;
    if (widget.permissions.isEmpty) return true;
    return widget.permissions.every((slug) {
      final permission = _permissionFromSlug(slug);
      return permission == null || rbac.hasPermission(permission);
    });
  }).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
}

bool canManageDynamicWidgets(RbacService rbac) =>
    rbac.hasManagePermission(Permission.manageDynamicWidgets);
