import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'receipt_models.dart';

/// Search query for receipt list.
final parentReceiptSearchProvider = StateProvider<String>((ref) => '');

/// Active receipt category filter.
final parentReceiptFilterProvider = StateProvider<ReceiptFilter>(
  (ref) => ReceiptFilter.all,
);

/// Loading flag for API integration.
final parentReceiptsLoadingProvider = StateProvider<bool>((ref) => false);

/// Error flag for API integration.
final parentReceiptsErrorProvider = StateProvider<bool>((ref) => false);

/// Empty-state toggle.
final parentReceiptsEmptyProvider = StateProvider<bool>((ref) => false);

final _parentReceiptsBaseProvider = Provider<List<FeeReceipt>>(
  (ref) => _mockReceipts(),
);

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

List<FeeReceipt> _mockReceipts() {
  return const [
    FeeReceipt(
      id: 'rcpt_term_1',
      receiptNumber: 'APS-2026-TERM_1',
      title: 'Term 1 — Full payment',
      dateLabel: '15 Apr 2026',
      amount: 8000,
      paymentMethod: 'UPI',
      statusLabel: 'Paid',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      category: 'term',
      lineItems: [
        ReceiptLineItem(label: 'Tuition', amount: 6500),
        ReceiptLineItem(label: 'Transport', amount: 1000),
        ReceiptLineItem(label: 'Activity', amount: 500),
      ],
    ),
    FeeReceipt(
      id: 'rcpt_ph_2',
      receiptNumber: 'APS-2026-ADM-001',
      title: 'Admission fee',
      dateLabel: '2 Mar 2026',
      amount: 5000,
      paymentMethod: 'Net Banking',
      statusLabel: 'Paid',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      category: 'admission',
      lineItems: [
        ReceiptLineItem(label: 'Admission fee', amount: 4500),
        ReceiptLineItem(label: 'Registration', amount: 500),
      ],
    ),
    FeeReceipt(
      id: 'rcpt_ph_3',
      receiptNumber: 'APS-2026-TRN-Q1',
      title: 'Transport — Q1',
      dateLabel: '10 Jan 2026',
      amount: 1500,
      paymentMethod: 'Card',
      statusLabel: 'Paid',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      category: 'transport',
      lineItems: [
        ReceiptLineItem(label: 'Bus route A', amount: 1200),
        ReceiptLineItem(label: 'Fuel surcharge', amount: 300),
      ],
    ),
    FeeReceipt(
      id: 'rcpt_ph_4',
      receiptNumber: 'APS-2025-ACT-014',
      title: 'Activity kit',
      dateLabel: '5 Dec 2025',
      amount: 800,
      paymentMethod: 'UPI',
      statusLabel: 'Paid',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      category: 'term',
      lineItems: [
        ReceiptLineItem(label: 'Sports kit', amount: 500),
        ReceiptLineItem(label: 'Lab apron', amount: 300),
      ],
    ),
  ];
}
