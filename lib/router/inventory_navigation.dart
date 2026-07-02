import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/inventory/allocation/inventory_allocation_screen.dart';
import '../features/inventory/assets/inventory_assets_screen.dart';
import '../features/inventory/categories/inventory_categories_screen.dart';
import '../features/inventory/dashboard/inventory_dashboard_screen.dart';
import '../features/inventory/maintenance/inventory_maintenance_screen.dart';
import '../features/inventory/procurement/inventory_procurement_screen.dart';
import '../features/inventory/reports/inventory_reports_screen.dart';
import '../features/inventory/stock/inventory_stock_approvals_screen.dart';
import '../features/inventory/stock/inventory_stock_screen.dart';
import '../features/inventory/vendors/inventory_vendors_screen.dart';
import '../features/inventory/intelligence/inventory_copilot_screen.dart';
import '../features/inventory/intelligence/inventory_lifecycle_screen.dart';
import 'route_names.dart';

String? inventoryRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.inventory) {
    return RouteNames.inventoryDashboard;
  }
  return null;
}

Widget inventoryDashboardRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const InventoryDashboardScreen();
}

Widget inventoryAssetsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const InventoryAssetsScreen();
}

Widget inventoryCategoriesRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const InventoryCategoriesScreen();
}

Widget inventoryAllocationRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const InventoryAllocationScreen();
}

Widget inventoryMaintenanceRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const InventoryMaintenanceScreen();
}

Widget inventoryProcurementRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const InventoryProcurementScreen();
}

Widget inventoryVendorsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const InventoryVendorsScreen();
}

Widget inventoryStockRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const InventoryStockScreen();
}

Widget inventoryStockApprovalsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const InventoryStockApprovalsScreen();
}

Widget inventoryReportsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const InventoryReportsScreen();
}

Widget inventoryCopilotRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const InventoryCopilotScreen();
}

Widget inventoryLifecycleRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const InventoryLifecycleScreen();
}
