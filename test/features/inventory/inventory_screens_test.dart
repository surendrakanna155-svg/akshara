import 'package:akshara_erp/features/inventory/allocation/inventory_allocation_screen.dart';
import 'package:akshara_erp/features/inventory/assets/inventory_assets_screen.dart';
import 'package:akshara_erp/features/inventory/categories/inventory_categories_screen.dart';
import 'package:akshara_erp/features/inventory/dashboard/inventory_dashboard_screen.dart';
import 'package:akshara_erp/features/inventory/maintenance/inventory_maintenance_screen.dart';
import 'package:akshara_erp/features/inventory/procurement/inventory_procurement_screen.dart';
import 'package:akshara_erp/features/inventory/reports/inventory_reports_screen.dart';
import 'package:akshara_erp/features/inventory/vendors/inventory_vendors_screen.dart';
import 'package:akshara_erp/features/inventory/inventory_providers.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_helpers.dart';

void useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> pumpInventoryScreen(
  WidgetTester tester,
  Widget screen, {
  Size viewport = const Size(1440, 900),
  List<Override> overrides = const [],
}) async {
  useViewport(tester, viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('Inventory screens — desktop', () {
    testWidgets('InventoryDashboardScreen renders KPIs', (tester) async {
      await pumpInventoryScreen(tester, const InventoryDashboardScreen());

      expect(find.text('Total Assets'), findsOneWidget);
      expect(find.text('Recent activity'), findsOneWidget);
    });

    testWidgets('InventoryDashboardScreen shows loading state', (tester) async {
      useViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            inventoryDashboardLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const InventoryDashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('InventoryAssetsScreen renders asset registry', (tester) async {
      await pumpInventoryScreen(tester, const InventoryAssetsScreen());

      expect(find.text('Asset registry'), findsOneWidget);
      expect(find.text('INV-AST-1042'), findsOneWidget);
    });

    testWidgets('InventoryCategoriesScreen renders category catalog', (
      tester,
    ) async {
      await pumpInventoryScreen(tester, const InventoryCategoriesScreen());

      expect(find.text('Category catalog'), findsOneWidget);
      expect(find.text('Electronics'), findsWidgets);
    });

    testWidgets('InventoryAllocationScreen renders cross-module allocations', (
      tester,
    ) async {
      await pumpInventoryScreen(tester, const InventoryAllocationScreen());

      expect(find.text('Asset allocation'), findsOneWidget);
      expect(find.text('HR-EMP-101'), findsOneWidget);
    });

    testWidgets('InventoryMaintenanceScreen renders maintenance schedule', (
      tester,
    ) async {
      await pumpInventoryScreen(tester, const InventoryMaintenanceScreen());

      expect(find.text('Maintenance schedule'), findsOneWidget);
      expect(find.text('Hostel Dining Chairs (x50)'), findsOneWidget);
    });

    testWidgets('InventoryProcurementScreen renders purchase orders', (
      tester,
    ) async {
      await pumpInventoryScreen(tester, const InventoryProcurementScreen());

      expect(find.text('Purchase orders'), findsOneWidget);
      expect(find.text('PO-2026-0142'), findsOneWidget);
    });

    testWidgets('InventoryVendorsScreen renders vendor directory', (
      tester,
    ) async {
      await pumpInventoryScreen(tester, const InventoryVendorsScreen());

      expect(find.text('Vendor directory'), findsOneWidget);
      expect(find.text('TechServe Solutions'), findsOneWidget);
    });

    testWidgets('InventoryReportsScreen renders report catalog', (
      tester,
    ) async {
      await pumpInventoryScreen(tester, const InventoryReportsScreen());

      expect(find.text('Report catalog'), findsOneWidget);
      expect(find.text('Asset Register'), findsOneWidget);
    });
  });
}
