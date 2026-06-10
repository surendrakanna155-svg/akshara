import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../finance_async_state.dart';
import '../inventory_finance/inventory_finance_models.dart';

enum FinanceReconciliationTab {
  overview,
  timeline,
  goodsReceipts,
  postings,
  vendors,
}

final financeReconciliationTabProvider =
    StateProvider<FinanceReconciliationTab>((ref) {
  return FinanceReconciliationTab.overview;
});

final financeReconciliationLoadingProvider = StateProvider<bool>((ref) => false);
final financeReconciliationErrorProvider = StateProvider<bool>((ref) => false);

final financeReconciliationQueryProvider = Provider<RepositoryQuery>((ref) {
  return ref.watch(repositoryQueryProvider);
});

final financeReconciliationDashboardFutureProvider =
    FutureProvider<InventoryFinanceReconciliationDashboard>((ref) async {
  return ref.read(inventoryFinanceRepositoryProvider).getReconciliationDashboard(
        query: ref.watch(financeReconciliationQueryProvider),
      );
});

final financeReconciliationTimelineFutureProvider =
    FutureProvider<List<InventoryFinanceTimelineEntry>>((ref) async {
  return ref.read(inventoryFinanceRepositoryProvider).getTimeline(
        query: ref.watch(financeReconciliationQueryProvider),
      );
});

final financeReconciliationGoodsReceiptsFutureProvider =
    FutureProvider<PaginatedResult<InventoryFinanceGoodsReceiptSummary>>((ref) async {
  return ref.read(inventoryFinanceRepositoryProvider).getGoodsReceipts(
        query: ref.watch(financeReconciliationQueryProvider),
      );
});

final financeReconciliationPostingsFutureProvider =
    FutureProvider<PaginatedResult<InventoryFinancePosting>>((ref) async {
  return ref.read(inventoryFinanceRepositoryProvider).getPostings(
        query: ref.watch(financeReconciliationQueryProvider),
      );
});

final financeReconciliationVendorsFutureProvider =
    FutureProvider<PaginatedResult<InventoryFinanceVendor>>((ref) async {
  return ref.read(inventoryFinanceRepositoryProvider).getVendors(
        query: ref.watch(financeReconciliationQueryProvider),
      );
});

final financeSelectedGoodsReceiptIdProvider =
    StateProvider<String?>((ref) => 'grn_if_1');

final financeSelectedVendorIdProvider =
    StateProvider<String?>((ref) => 'vendor_if_1');

final financeReconciliationGoodsReceiptDetailFutureProvider =
    FutureProvider<InventoryFinanceGoodsReceiptDetail?>((ref) async {
  final id = ref.watch(financeSelectedGoodsReceiptIdProvider);
  if (id == null) return null;
  return ref.read(inventoryFinanceRepositoryProvider).getGoodsReceipt(
        query: ref.watch(financeReconciliationQueryProvider),
        goodsReceiptId: id,
      );
});

final financeReconciliationVendorTransactionsFutureProvider =
    FutureProvider<List<InventoryFinanceVendorTransaction>>((ref) async {
  final vendorId = ref.watch(financeSelectedVendorIdProvider);
  if (vendorId == null) return const [];
  return ref.read(inventoryFinanceRepositoryProvider).getVendorTransactions(
        query: ref.watch(financeReconciliationQueryProvider),
        vendorId: vendorId,
      );
});

final financeReconciliationDashboardViewStateProvider =
    Provider<FinanceViewState<InventoryFinanceReconciliationDashboard>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeReconciliationDashboardFutureProvider),
    forceLoading: ref.watch(financeReconciliationLoadingProvider),
    forceError: ref.watch(financeReconciliationErrorProvider),
  );
});

final financeReconciliationTimelineViewStateProvider =
    Provider<FinanceViewState<List<InventoryFinanceTimelineEntry>>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeReconciliationTimelineFutureProvider),
    forceLoading: ref.watch(financeReconciliationLoadingProvider),
    forceError: ref.watch(financeReconciliationErrorProvider),
    isDataEmpty: (items) => items.isEmpty,
  );
});

final financeReconciliationGoodsReceiptsViewStateProvider =
    Provider<FinanceViewState<PaginatedResult<InventoryFinanceGoodsReceiptSummary>>>(
        (ref) {
  return resolveFinanceAsync(
    ref.watch(financeReconciliationGoodsReceiptsFutureProvider),
    forceLoading: ref.watch(financeReconciliationLoadingProvider),
    forceError: ref.watch(financeReconciliationErrorProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});

final financeReconciliationPostingsViewStateProvider =
    Provider<FinanceViewState<PaginatedResult<InventoryFinancePosting>>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeReconciliationPostingsFutureProvider),
    forceLoading: ref.watch(financeReconciliationLoadingProvider),
    forceError: ref.watch(financeReconciliationErrorProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});

final financeReconciliationVendorsViewStateProvider =
    Provider<FinanceViewState<PaginatedResult<InventoryFinanceVendor>>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeReconciliationVendorsFutureProvider),
    forceLoading: ref.watch(financeReconciliationLoadingProvider),
    forceError: ref.watch(financeReconciliationErrorProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});

void invalidateFinanceReconciliationReads(Ref ref) {
  ref.invalidate(financeReconciliationDashboardFutureProvider);
  ref.invalidate(financeReconciliationTimelineFutureProvider);
  ref.invalidate(financeReconciliationGoodsReceiptsFutureProvider);
  ref.invalidate(financeReconciliationPostingsFutureProvider);
  ref.invalidate(financeReconciliationVendorsFutureProvider);
  ref.invalidate(financeReconciliationGoodsReceiptDetailFutureProvider);
  ref.invalidate(financeReconciliationVendorTransactionsFutureProvider);
}

void retryFinanceReconciliation(WidgetRef ref) {
  ref.invalidate(financeReconciliationDashboardFutureProvider);
  ref.invalidate(financeReconciliationTimelineFutureProvider);
  ref.invalidate(financeReconciliationGoodsReceiptsFutureProvider);
  ref.invalidate(financeReconciliationPostingsFutureProvider);
  ref.invalidate(financeReconciliationVendorsFutureProvider);
  ref.invalidate(financeReconciliationGoodsReceiptDetailFutureProvider);
  ref.invalidate(financeReconciliationVendorTransactionsFutureProvider);
}
