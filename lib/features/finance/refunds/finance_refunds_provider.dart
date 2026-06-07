import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeRefundsLoadingProvider = StateProvider<bool>((ref) => false);
final financeRefundsErrorProvider = StateProvider<bool>((ref) => false);
final financeRefundsEmptyProvider = StateProvider<bool>((ref) => false);
final financeRefundsFilterProvider = StateProvider<int>((ref) => 0);
final financeSelectedRefundIdProvider = StateProvider<String?>((ref) => null);

final financeRefundsFutureProvider = FutureProvider<List<RefundRequest>>((ref) async {
return ref.read(financeRepositoryProvider).getRefundRequests(query: ref.watch(repositoryQueryProvider));
});

final financeRefundsProvider = Provider<List<RefundRequest>>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(financeRefundsFutureProvider),
    manualLoading: ref.watch(financeRefundsLoadingProvider), manualError: ref.watch(financeRefundsErrorProvider), manualEmpty: ref.watch(financeRefundsEmptyProvider),
  ) ?? const [];
});

final financeRefundsViewStateProvider =
    Provider<FinanceViewState<List<RefundRequest>>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeRefundsFutureProvider),
    forceLoading: ref.watch(financeRefundsLoadingProvider),
    forceError: ref.watch(financeRefundsErrorProvider),
    forceEmpty: ref.watch(financeRefundsEmptyProvider),
    isDataEmpty: (refunds) => refunds.isEmpty,
  );
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
