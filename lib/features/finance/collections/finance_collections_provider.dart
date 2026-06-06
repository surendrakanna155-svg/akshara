import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_models.dart';

final financeCollectionsLoadingProvider = StateProvider<bool>((ref) => false);
final financeCollectionsErrorProvider = StateProvider<bool>((ref) => false);
final financeCollectionsEmptyProvider = StateProvider<bool>((ref) => false);
final financeCollectionFilterProvider = StateProvider<int>((ref) => 0);
final financeReceiptSearchProvider = StateProvider<String>((ref) => '');

final financeCollectionsProvider = Provider<List<CollectionPayment>>((ref) {
  if (ref.watch(financeCollectionsLoadingProvider)) return const [];
  if (ref.watch(financeCollectionsErrorProvider)) return const [];
  if (ref.watch(financeCollectionsEmptyProvider)) return const [];
  return ref.read(financeRepositoryProvider).getCollections();
});

final financeDailySummaryProvider = Provider<DailyCollectionSummary>((ref) {
  if (ref.watch(financeCollectionsLoadingProvider)) {
    return const DailyCollectionSummary(
      dateLabel: '—',
      totalCollected: '—',
      transactionCount: 0,
      cashAmount: '—',
      upiAmount: '—',
      pendingReconciliation: 0,
    );
  }
  return ref.read(financeRepositoryProvider).getDailySummary();
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
