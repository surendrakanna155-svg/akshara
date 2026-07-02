import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';
import 'inventory_models.dart';

/// Primary inventory sub-navigation tabs (INV-01 → INV-08).
const List<InventoryScreen> kInventoryNavScreens = [
  InventoryScreen.dashboard,
  InventoryScreen.assets,
  InventoryScreen.categories,
  InventoryScreen.allocation,
  InventoryScreen.maintenance,
  InventoryScreen.procurement,
  InventoryScreen.vendors,
  InventoryScreen.stock,
  InventoryScreen.stockApprovals,
  InventoryScreen.reports,
  InventoryScreen.copilot,
  InventoryScreen.lifecycle,
];

extension InventoryScreenRoutes on InventoryScreen {
  String get route => switch (this) {
        InventoryScreen.dashboard => RouteNames.inventoryDashboard,
        InventoryScreen.assets => RouteNames.inventoryAssets,
        InventoryScreen.categories => RouteNames.inventoryCategories,
        InventoryScreen.allocation => RouteNames.inventoryAllocation,
        InventoryScreen.maintenance => RouteNames.inventoryMaintenance,
        InventoryScreen.procurement => RouteNames.inventoryProcurement,
        InventoryScreen.vendors => RouteNames.inventoryVendors,
        InventoryScreen.stock => RouteNames.inventoryStock,
        InventoryScreen.stockApprovals => RouteNames.inventoryStockApprovals,
        InventoryScreen.reports => RouteNames.inventoryReports,
        InventoryScreen.copilot => RouteNames.inventoryCopilot,
        InventoryScreen.lifecycle => RouteNames.inventoryLifecycle,
      };
}

List<AdminBreadcrumb> inventoryBreadcrumbs(InventoryScreen screen) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Inventory',
      route: RouteNames.inventoryDashboard,
    ),
    AdminBreadcrumb(label: screen.label),
  ];
}

InventoryScreen? inventoryScreenForLocation(String location) {
  for (final screen in kInventoryNavScreens) {
    if (location == screen.route) {
      return screen;
    }
  }
  if (location == RouteNames.inventory) {
    return InventoryScreen.dashboard;
  }
  return null;
}
