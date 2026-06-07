import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tenant/tenant_provider.dart';
import '../../core/providers/repository_future.dart';

import '../../core/repositories/paginated_result.dart';
import '../../core/repositories/repository_providers.dart';
import 'inventory_models.dart';

// INV-01 Dashboard
final inventoryDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final inventoryDashboardErrorProvider = StateProvider<bool>((ref) => false);
final inventoryDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final inventoryDashboardFilterProvider = StateProvider<int>((ref) => 0);

final inventoryDashboardFutureProvider = FutureProvider<InventoryDashboardData>((ref) async {
return await ref.read(inventoryRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

final inventoryDashboardProvider = Provider<InventoryDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(inventoryDashboardFutureProvider),
    manualLoading: ref.watch(inventoryDashboardLoadingProvider), manualError: ref.watch(inventoryDashboardErrorProvider), manualEmpty: ref.watch(inventoryDashboardEmptyProvider),
  );
});

// INV-02 Assets
final inventoryAssetsLoadingProvider = StateProvider<bool>((ref) => false);
final inventoryAssetsErrorProvider = StateProvider<bool>((ref) => false);
final inventoryAssetsEmptyProvider = StateProvider<bool>((ref) => false);
final inventoryAssetsFilterProvider = StateProvider<int>((ref) => 0);

final inventoryAssetsFutureProvider = FutureProvider<PaginatedResult<InventoryAsset>>((ref) async {
return ref.read(inventoryRepositoryProvider).getAssets(query: ref.watch(repositoryQueryProvider));
});

final inventoryAssetsProvider = Provider<List<InventoryAsset>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(inventoryAssetsFutureProvider),
    manualLoading: ref.watch(inventoryAssetsLoadingProvider), manualError: ref.watch(inventoryAssetsErrorProvider), manualEmpty: ref.watch(inventoryAssetsEmptyProvider),
  )?.items ?? const [];
});

final inventoryFilteredAssetsProvider = Provider<List<InventoryAsset>>((ref) {
  final assets = ref.watch(inventoryAssetsProvider);
  if (assets == null) return const [];
  final filterIndex = ref.watch(inventoryAssetsFilterProvider);
  return switch (filterIndex) {
    1 => assets
        .where((a) => a.status == InventoryAssetStatus.available)
        .toList(),
    2 => assets
        .where((a) => a.status == InventoryAssetStatus.allocated)
        .toList(),
    3 => assets
        .where((a) => a.status == InventoryAssetStatus.maintenance)
        .toList(),
    4 => assets
        .where((a) => a.status == InventoryAssetStatus.retired)
        .toList(),
    _ => assets,
  };
});

// INV-03 Categories
final inventoryCategoriesLoadingProvider = StateProvider<bool>((ref) => false);
final inventoryCategoriesErrorProvider = StateProvider<bool>((ref) => false);
final inventoryCategoriesEmptyProvider = StateProvider<bool>((ref) => false);
final inventoryCategoriesFilterProvider = StateProvider<int>((ref) => 0);

final inventoryCategoriesFutureProvider = FutureProvider<PaginatedResult<InventoryCategory>>((ref) async {
return ref.read(inventoryRepositoryProvider).getCategories(query: ref.watch(repositoryQueryProvider));
});

final inventoryCategoriesProvider = Provider<List<InventoryCategory>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(inventoryCategoriesFutureProvider),
    manualLoading: ref.watch(inventoryCategoriesLoadingProvider), manualError: ref.watch(inventoryCategoriesErrorProvider), manualEmpty: ref.watch(inventoryCategoriesEmptyProvider),
  )?.items ?? const [];
});

final inventoryFilteredCategoriesProvider = Provider<List<InventoryCategory>>(
  (ref) {
    final categories = ref.watch(inventoryCategoriesProvider);
    if (categories == null) return const [];
    final filterIndex = ref.watch(inventoryCategoriesFilterProvider);
    return switch (filterIndex) {
      1 => categories
          .where((c) => c.type == InventoryCategoryType.equipment)
          .toList(),
      2 => categories
          .where((c) => c.type == InventoryCategoryType.furniture)
          .toList(),
      3 => categories
          .where((c) => c.type == InventoryCategoryType.electronics)
          .toList(),
      4 => categories
          .where((c) => c.type == InventoryCategoryType.consumable)
          .toList(),
      _ => categories,
    };
  },
);

// INV-04 Allocation
final inventoryAllocationLoadingProvider = StateProvider<bool>((ref) => false);
final inventoryAllocationErrorProvider = StateProvider<bool>((ref) => false);
final inventoryAllocationEmptyProvider = StateProvider<bool>((ref) => false);
final inventoryAllocationFilterProvider = StateProvider<int>((ref) => 0);

final inventoryAllocationsFutureProvider =
    FutureProvider<PaginatedResult<InventoryAllocation>>((ref) async {
  return ref.read(inventoryRepositoryProvider).getAllocations(
        query: ref.watch(repositoryQueryProvider),
      );
});

final inventoryAllocationsProvider =
    Provider<List<InventoryAllocation>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(inventoryAllocationsFutureProvider),
    manualLoading: ref.watch(inventoryAllocationLoadingProvider),
    manualError: ref.watch(inventoryAllocationErrorProvider),
    manualEmpty: ref.watch(inventoryAllocationEmptyProvider),
  )?.items;
});

final inventoryFilteredAllocationsProvider =
    Provider<List<InventoryAllocation>>((ref) {
  final allocations = ref.watch(inventoryAllocationsProvider);
  if (allocations == null) return const [];
  final filterIndex = ref.watch(inventoryAllocationFilterProvider);
  return switch (filterIndex) {
    1 => allocations
        .where((a) => a.status == InventoryAllocationStatus.active)
        .toList(),
    2 => allocations
        .where((a) => a.status == InventoryAllocationStatus.pendingReturn)
        .toList(),
    3 => allocations
        .where((a) => a.status == InventoryAllocationStatus.overdue)
        .toList(),
    _ => allocations,
  };
});

// INV-05 Maintenance
final inventoryMaintenanceLoadingProvider = StateProvider<bool>((ref) => false);
final inventoryMaintenanceErrorProvider = StateProvider<bool>((ref) => false);
final inventoryMaintenanceEmptyProvider = StateProvider<bool>((ref) => false);
final inventoryMaintenanceFilterProvider = StateProvider<int>((ref) => 0);

final inventoryMaintenanceFutureProvider =
    FutureProvider<PaginatedResult<InventoryMaintenanceRecord>>((ref) async {
  return ref.read(inventoryRepositoryProvider).getMaintenanceRecords(
        query: ref.watch(repositoryQueryProvider),
      );
});

final inventoryMaintenanceProvider =
    Provider<List<InventoryMaintenanceRecord>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(inventoryMaintenanceFutureProvider),
    manualLoading: ref.watch(inventoryMaintenanceLoadingProvider),
    manualError: ref.watch(inventoryMaintenanceErrorProvider),
    manualEmpty: ref.watch(inventoryMaintenanceEmptyProvider),
  )?.items;
});

final inventoryFilteredMaintenanceProvider =
    Provider<List<InventoryMaintenanceRecord>>((ref) {
  final records = ref.watch(inventoryMaintenanceProvider);
  if (records == null) return const [];
  final filterIndex = ref.watch(inventoryMaintenanceFilterProvider);
  return switch (filterIndex) {
    1 => records
        .where((r) => r.status == InventoryMaintenanceStatus.scheduled)
        .toList(),
    2 => records
        .where((r) => r.status == InventoryMaintenanceStatus.inProgress)
        .toList(),
    3 => records
        .where((r) => r.status == InventoryMaintenanceStatus.overdue)
        .toList(),
    _ => records,
  };
});

// INV-06 Procurement
final inventoryProcurementLoadingProvider = StateProvider<bool>((ref) => false);
final inventoryProcurementErrorProvider = StateProvider<bool>((ref) => false);
final inventoryProcurementEmptyProvider = StateProvider<bool>((ref) => false);
final inventoryProcurementFilterProvider = StateProvider<int>((ref) => 0);

final inventoryProcurementFutureProvider =
    FutureProvider<PaginatedResult<InventoryProcurementOrder>>((ref) async {
  return ref.read(inventoryRepositoryProvider).getProcurementOrders(
        query: ref.watch(repositoryQueryProvider),
      );
});

final inventoryProcurementProvider =
    Provider<List<InventoryProcurementOrder>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(inventoryProcurementFutureProvider),
    manualLoading: ref.watch(inventoryProcurementLoadingProvider),
    manualError: ref.watch(inventoryProcurementErrorProvider),
    manualEmpty: ref.watch(inventoryProcurementEmptyProvider),
  )?.items;
});

final inventoryFilteredProcurementProvider =
    Provider<List<InventoryProcurementOrder>>((ref) {
  final orders = ref.watch(inventoryProcurementProvider);
  if (orders == null) return const [];
  final filterIndex = ref.watch(inventoryProcurementFilterProvider);
  return switch (filterIndex) {
    1 => orders
        .where((o) => o.status == InventoryProcurementStatus.draft)
        .toList(),
    2 => orders
        .where((o) => o.status == InventoryProcurementStatus.ordered)
        .toList(),
    3 => orders
        .where((o) => o.status == InventoryProcurementStatus.received)
        .toList(),
    _ => orders,
  };
});

// INV-07 Vendors
final inventoryVendorsLoadingProvider = StateProvider<bool>((ref) => false);
final inventoryVendorsErrorProvider = StateProvider<bool>((ref) => false);
final inventoryVendorsEmptyProvider = StateProvider<bool>((ref) => false);
final inventoryVendorsFilterProvider = StateProvider<int>((ref) => 0);

final inventoryVendorsFutureProvider = FutureProvider<PaginatedResult<InventoryVendor>>((ref) async {
return ref.read(inventoryRepositoryProvider).getVendors(query: ref.watch(repositoryQueryProvider));
});

final inventoryVendorsProvider = Provider<List<InventoryVendor>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(inventoryVendorsFutureProvider),
    manualLoading: ref.watch(inventoryVendorsLoadingProvider), manualError: ref.watch(inventoryVendorsErrorProvider), manualEmpty: ref.watch(inventoryVendorsEmptyProvider),
  )?.items ?? const [];
});

final inventoryFilteredVendorsProvider = Provider<List<InventoryVendor>>(
  (ref) {
    final vendors = ref.watch(inventoryVendorsProvider);
    if (vendors == null) return const [];
    final filterIndex = ref.watch(inventoryVendorsFilterProvider);
    return switch (filterIndex) {
      1 => vendors
          .where((v) => v.status == InventoryVendorStatus.active)
          .toList(),
      2 => vendors
          .where((v) => v.status == InventoryVendorStatus.pending)
          .toList(),
      3 => vendors
          .where((v) => v.status == InventoryVendorStatus.inactive)
          .toList(),
      _ => vendors,
    };
  },
);

// INV-08 Reports
final inventoryReportsLoadingProvider = StateProvider<bool>((ref) => false);
final inventoryReportsErrorProvider = StateProvider<bool>((ref) => false);
final inventoryReportsEmptyProvider = StateProvider<bool>((ref) => false);

final inventoryReportsFutureProvider = FutureProvider<InventoryReportsData>((ref) async {
return await ref.read(inventoryRepositoryProvider).getReports(query: ref.watch(repositoryQueryProvider));
});

final inventoryReportsProvider = Provider<InventoryReportsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(inventoryReportsFutureProvider),
    manualLoading: ref.watch(inventoryReportsLoadingProvider), manualError: ref.watch(inventoryReportsErrorProvider), manualEmpty: ref.watch(inventoryReportsEmptyProvider),
  );
});
