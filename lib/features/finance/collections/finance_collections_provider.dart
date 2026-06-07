import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeCollectionsLoadingProvider = StateProvider<bool>((ref) => false);
final financeCollectionsErrorProvider = StateProvider<bool>((ref) => false);
final financeCollectionsEmptyProvider = StateProvider<bool>((ref) => false);
final financeCollectionFilterProvider = StateProvider<int>((ref) => 0);
final financeReceiptSearchProvider = StateProvider<String>((ref) => '');
final financeCollectionsPageProvider = StateProvider<int>((ref) => 1);

final financeCollectionsQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(financeCollectionsPageProvider);
  return baseQuery.withPage(page);
});

final financeCollectionsFutureProvider =
    FutureProvider<PaginatedResult<CollectionPayment>>((ref) async {
  return ref.read(financeRepositoryProvider).getCollections(
        query: ref.watch(financeCollectionsQueryProvider),
      );
});

final financeCollectionsPageResultProvider =
    Provider<PaginatedResult<CollectionPayment>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(financeCollectionsFutureProvider),
    manualLoading: ref.watch(financeCollectionsLoadingProvider),
    manualError: ref.watch(financeCollectionsErrorProvider),
    manualEmpty: ref.watch(financeCollectionsEmptyProvider),
  );
});

final financeCollectionsProvider = Provider<List<CollectionPayment>>((ref) {
  return ref.watch(financeCollectionsPageResultProvider)?.items ?? const [];
});

final financeCollectionsViewStateProvider =
    Provider<FinanceViewState<PaginatedResult<CollectionPayment>>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeCollectionsFutureProvider),
    forceLoading: ref.watch(financeCollectionsLoadingProvider),
    forceError: ref.watch(financeCollectionsErrorProvider),
    forceEmpty: ref.watch(financeCollectionsEmptyProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});

final financeDailySummaryFutureProvider =
    FutureProvider<DailyCollectionSummary>((ref) async {
  return ref
      .read(financeRepositoryProvider)
      .getDailySummary(query: ref.watch(repositoryQueryProvider));
});

final financeDailySummaryProvider = Provider<DailyCollectionSummary>((ref) {
  return watchRepositoryFuture(
        ref,
        ref.watch(financeDailySummaryFutureProvider),
        manualLoading: false,
        manualError: false,
        manualEmpty: false,
      ) ??
      const DailyCollectionSummary(
        dateLabel: '—',
        totalCollected: '—',
        transactionCount: 0,
        cashAmount: '—',
        upiAmount: '—',
        pendingReconciliation: 0,
      );
});

final financeFilteredCollectionsProvider = Provider<List<CollectionPayment>>(
  (ref) {
    final payments = ref.watch(financeCollectionsProvider);
    final filterIndex = ref.watch(financeCollectionFilterProvider);
    final receiptQuery = ref.watch(financeReceiptSearchProvider).trim();

    var filtered = payments;
    filtered = switch (filterIndex) {
      1 => filtered
          .where((p) => p.status == CollectionStatus.completed)
          .toList(),
      2 => filtered
          .where((p) => p.status == CollectionStatus.pending)
          .toList(),
      3 => filtered.where((p) => p.mode == 'Cash').toList(),
      _ => filtered,
    };

    if (receiptQuery.isNotEmpty) {
      final q = receiptQuery.toLowerCase();
      filtered = filtered
          .where(
            (p) =>
                p.receiptNumber.toLowerCase().contains(q) ||
                p.studentName.toLowerCase().contains(q),
          )
          .toList();
    }

    return filtered;
  },
);
