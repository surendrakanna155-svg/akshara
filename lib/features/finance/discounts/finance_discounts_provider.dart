import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeDiscountsLoadingProvider = StateProvider<bool>((ref) => false);
final financeDiscountsErrorProvider = StateProvider<bool>((ref) => false);
final financeDiscountsEmptyProvider = StateProvider<bool>((ref) => false);
final financeDiscountsTabProvider = StateProvider<int>((ref) => 0);

final financeDiscountsFutureProvider = FutureProvider<DiscountsDashboardData>((ref) async {
return await ref.read(financeRepositoryProvider).getDiscountsDashboard(query: ref.watch(repositoryQueryProvider));
});

final financeDiscountsProvider = Provider<DiscountsDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(financeDiscountsFutureProvider),
    manualLoading: ref.watch(financeDiscountsLoadingProvider), manualError: ref.watch(financeDiscountsErrorProvider), manualEmpty: ref.watch(financeDiscountsEmptyProvider),
  );
});

final financeDiscountsViewStateProvider =
    Provider<FinanceViewState<DiscountsDashboardData>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeDiscountsFutureProvider),
    forceLoading: ref.watch(financeDiscountsLoadingProvider),
    forceError: ref.watch(financeDiscountsErrorProvider),
    forceEmpty: ref.watch(financeDiscountsEmptyProvider),
  );
});

// STEP-5 — fee reductions (scholarship awards + discount applications) that
// actually reduce a student's payable via the invoice-scoped maker-checker.
// Unfiltered (all statuses) so the discounts screen can show a "Pending
// awards" section (Approve/Reject) and an "Approved" section (Reverse) from
// one read; mutations invalidate this via `invalidateFeeReductions`.
final financeFeeReductionsFutureProvider =
    FutureProvider<List<FeeReduction>>((ref) async {
  return ref.read(financeRepositoryProvider).listFeeReductions(
        query: ref.watch(repositoryQueryProvider),
      );
});

final financeFeeReductionsProvider = Provider<List<FeeReduction>>((ref) {
  return ref.watch(financeFeeReductionsFutureProvider).valueOrNull ?? const [];
});

final financePendingFeeReductionsProvider = Provider<List<FeeReduction>>((ref) {
  return ref
      .watch(financeFeeReductionsProvider)
      .where((r) => r.status == FeeReductionStatus.pending)
      .toList(growable: false);
});

final financeApprovedFeeReductionsProvider = Provider<List<FeeReduction>>((ref) {
  return ref
      .watch(financeFeeReductionsProvider)
      .where((r) => r.status == FeeReductionStatus.approved)
      .toList(growable: false);
});
