import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'receipt_models.dart';

/// Search query for receipt list.
final parentReceiptSearchProvider = StateProvider<String>((ref) => '');

/// Active receipt category filter.
final parentReceiptFilterProvider = StateProvider<ReceiptFilter>(
  (ref) => ReceiptFilter.all,
);

final parentReceiptsLoadingProvider = StateProvider<bool>((ref) => false);
final parentReceiptsErrorProvider = StateProvider<bool>((ref) => false);
final parentReceiptsEmptyProvider = StateProvider<bool>((ref) => false);

final parentReceiptsFutureProvider = FutureProvider<List<FeeReceipt>>((ref) async {
  return ref.read(parentRepositoryProvider).getReceipts(query: ref.watch(repositoryQueryProvider));
});

final _parentReceiptsBaseProvider = Provider<List<FeeReceipt>>((ref) {
  final items = watchRepositoryFuture(
    ref,
    ref.watch(parentReceiptsFutureProvider),
    manualLoading: ref.watch(parentReceiptsLoadingProvider),
    manualError: ref.watch(parentReceiptsErrorProvider),
    manualEmpty: ref.watch(parentReceiptsEmptyProvider),
  );
  return items ?? ref.watch(parentReceiptsFutureProvider).value ?? const [];
});

/// Filtered and searched receipts.
final parentReceiptsListProvider = Provider<List<FeeReceipt>>((ref) {
  if (ref.watch(parentReceiptsEmptyProvider)) {
    return const [];
  }

  final query = ref.watch(parentReceiptSearchProvider).trim().toLowerCase();
  final filter = ref.watch(parentReceiptFilterProvider);
  var items = ref.watch(_parentReceiptsBaseProvider);

  items = switch (filter) {
    ReceiptFilter.all => items,
    ReceiptFilter.term => items
        .where((item) => item.category == 'term')
        .toList(growable: false),
    ReceiptFilter.transport => items
        .where((item) => item.category == 'transport')
        .toList(growable: false),
    ReceiptFilter.admission => items
        .where((item) => item.category == 'admission')
        .toList(growable: false),
  };

  if (query.isEmpty) {
    return items;
  }

  return items
      .where(
        (item) =>
            item.title.toLowerCase().contains(query) ||
            item.receiptNumber.toLowerCase().contains(query) ||
            item.dateLabel.toLowerCase().contains(query),
      )
      .toList(growable: false);
});

/// Screen payload with unread badge count.
final parentReceiptsDataProvider = Provider<ParentReceiptsData>((ref) {
  final receipts = ref.watch(parentReceiptsListProvider);
  return ParentReceiptsData(
    childName: 'Ravi Kumar',
    childClass: '8-A',
    receipts: receipts,
    unreadNotifications: 2,
  );
});

/// Lookup a receipt by id for detail screen.
final parentReceiptDetailProvider = Provider.family<FeeReceipt?, String>(
  (ref, receiptId) {
    final items = ref.watch(_parentReceiptsBaseProvider);
    for (final item in items) {
      if (item.id == receiptId) {
        return item;
      }
    }
    return null;
  },
);

@immutable
class ParentReceiptsData {
  const ParentReceiptsData({
    required this.childName,
    required this.childClass,
    required this.receipts,
    required this.unreadNotifications,
  });

  final String childName;
  final String childClass;
  final List<FeeReceipt> receipts;
  final int unreadNotifications;
}
