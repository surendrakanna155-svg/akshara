import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return _mockPayments();
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
  return const DailyCollectionSummary(
    dateLabel: 'Today, 5 Jun 2026',
    totalCollected: '₹2,41,500',
    transactionCount: 18,
    cashAmount: '₹45,000',
    upiAmount: '₹1,96,500',
    pendingReconciliation: 2,
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

List<CollectionPayment> _mockPayments() {
  return const [
    CollectionPayment(
      id: 'col_1',
      receiptNumber: 'RCP-2026-8841',
      studentName: 'Arjun Patel',
      admissionNumber: 'ADM-2026-0138',
      amount: '₹62,000',
      mode: 'UPI',
      collectedAt: 'Today, 10:42',
      collectedBy: 'R. Kumar',
      status: CollectionStatus.completed,
      classLabel: '10',
    ),
    CollectionPayment(
      id: 'col_2',
      receiptNumber: 'RCP-2026-8840',
      studentName: 'Priya Sharma',
      admissionNumber: 'ADM-2025-0092',
      amount: '₹45,000',
      mode: 'Cash',
      collectedAt: 'Today, 09:15',
      collectedBy: 'S. Nair',
      status: CollectionStatus.completed,
      classLabel: '8',
    ),
    CollectionPayment(
      id: 'col_3',
      receiptNumber: 'RCP-2026-8839',
      studentName: 'Rohan Mehta',
      admissionNumber: 'ADM-2025-0114',
      amount: '₹38,500',
      mode: 'Card',
      collectedAt: 'Today, 08:30',
      collectedBy: 'R. Kumar',
      status: CollectionStatus.completed,
      classLabel: '9',
    ),
    CollectionPayment(
      id: 'col_4',
      receiptNumber: 'RCP-2026-8838',
      studentName: 'Ananya Reddy',
      admissionNumber: 'ADM-2026-0142',
      amount: '₹71,500',
      mode: 'UPI',
      collectedAt: 'Yesterday',
      collectedBy: 'R. Kumar',
      status: CollectionStatus.pending,
      classLabel: '5',
    ),
    CollectionPayment(
      id: 'col_5',
      receiptNumber: 'RCP-2026-8837',
      studentName: 'Emma Thomas',
      admissionNumber: 'ADM-2026-0135',
      amount: '₹85,000',
      mode: 'Bank Transfer',
      collectedAt: 'Yesterday',
      collectedBy: 'S. Nair',
      status: CollectionStatus.completed,
      classLabel: '7',
    ),
    CollectionPayment(
      id: 'col_6',
      receiptNumber: 'RCP-2026-8836',
      studentName: 'Kavya Iyer',
      admissionNumber: 'ADM-2025-0101',
      amount: '₹52,000',
      mode: 'UPI',
      collectedAt: '2 days ago',
      collectedBy: 'R. Kumar',
      status: CollectionStatus.refunded,
      classLabel: '6',
    ),
  ];
}
