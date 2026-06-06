import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_models.dart';

final financeRefundsLoadingProvider = StateProvider<bool>((ref) => false);
final financeRefundsErrorProvider = StateProvider<bool>((ref) => false);
final financeRefundsEmptyProvider = StateProvider<bool>((ref) => false);
final financeRefundsFilterProvider = StateProvider<int>((ref) => 0);
final financeSelectedRefundIdProvider = StateProvider<String?>((ref) => null);

final financeRefundsProvider = Provider<List<RefundRequest>>((ref) {
  if (ref.watch(financeRefundsLoadingProvider)) return const [];
  if (ref.watch(financeRefundsErrorProvider)) return const [];
  if (ref.watch(financeRefundsEmptyProvider)) return const [];
  return ref.read(financeRepositoryProvider).getRefundRequests();
});

final financeFilteredRefundsProvider = Provider<List<RefundRequest>>((ref) {
  final refunds = ref.watch(financeRefundsProvider);
  final filterIndex = ref.watch(financeRefundsFilterProvider);
  return switch (filterIndex) {
    1 => refunds.where((r) => r.status == RefundStatus.pending).toList(),
    2 => refunds.where((r) => r.status == RefundStatus.approved).toList(),
    3 => refunds.where((r) => r.status == RefundStatus.processed).toList(),
    _ => refunds,
  };
});

final financeSelectedRefundProvider = Provider<RefundRequest?>((ref) {
  final refunds = ref.watch(financeFilteredRefundsProvider);
  final selectedId = ref.watch(financeSelectedRefundIdProvider);
  if (selectedId != null) {
    for (final refund in refunds) {
      if (refund.id == selectedId) return refund;
    }
  }
  return refunds.isEmpty ? null : refunds.first;
});
