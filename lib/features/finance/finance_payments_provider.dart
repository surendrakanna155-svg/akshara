import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_future.dart';
import '../../core/repositories/paginated_result.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import 'finance_async_state.dart';
import 'finance_models.dart';

final financeQrPaymentSessionIdProvider = StateProvider<String?>((ref) => null);

final qrPaymentSessionProvider = FutureProvider<QrPaymentSession?>((ref) async {
  final sessionId = ref.watch(financeQrPaymentSessionIdProvider);
  if (sessionId == null || sessionId.isEmpty) {
    return null;
  }
  return ref.read(financeRepositoryProvider).getQrPaymentSession(
        query: ref.watch(repositoryQueryProvider),
        sessionId: sessionId,
      );
});

final offlinePaymentsLoadingProvider = StateProvider<bool>((ref) => false);
final offlinePaymentsErrorProvider = StateProvider<bool>((ref) => false);
final offlinePaymentsEmptyProvider = StateProvider<bool>((ref) => false);
final offlinePaymentsTabProvider = StateProvider<int>((ref) => 0);
final offlinePaymentsPageProvider = StateProvider<int>((ref) => 1);

final offlinePaymentsQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(offlinePaymentsPageProvider);
  return baseQuery.withPage(page);
});

final offlinePaymentsFutureProvider =
    FutureProvider<PaginatedResult<OfflinePaymentRecord>>((ref) async {
  return ref.read(financeRepositoryProvider).listOfflinePayments(
        query: ref.watch(offlinePaymentsQueryProvider),
      );
});

final offlinePaymentsPageResultProvider =
    Provider<PaginatedResult<OfflinePaymentRecord>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(offlinePaymentsFutureProvider),
    manualLoading: ref.watch(offlinePaymentsLoadingProvider),
    manualError: ref.watch(offlinePaymentsErrorProvider),
    manualEmpty: ref.watch(offlinePaymentsEmptyProvider),
  );
});

final offlinePaymentsProvider = Provider<List<OfflinePaymentRecord>>((ref) {
  return ref.watch(offlinePaymentsPageResultProvider)?.items ?? const [];
});

final offlinePaymentsViewStateProvider =
    Provider<FinanceViewState<PaginatedResult<OfflinePaymentRecord>>>((ref) {
  return resolveFinanceAsync(
    ref.watch(offlinePaymentsFutureProvider),
    forceLoading: ref.watch(offlinePaymentsLoadingProvider),
    forceError: ref.watch(offlinePaymentsErrorProvider),
    forceEmpty: ref.watch(offlinePaymentsEmptyProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});

final pendingOfflinePaymentsProvider =
    Provider<List<OfflinePaymentRecord>>((ref) {
  return ref
      .watch(offlinePaymentsProvider)
      .where(
        (item) => item.status == OfflinePaymentStatus.pendingReconciliation,
      )
      .toList(growable: false);
});

final reconciledOfflinePaymentsProvider =
    Provider<List<OfflinePaymentRecord>>((ref) {
  return ref
      .watch(offlinePaymentsProvider)
      .where((item) => item.status == OfflinePaymentStatus.reconciled)
      .toList(growable: false);
});

// FIN-R7: dishonoured instruments (cheque/DD/PDC bounces).
final bouncedOfflinePaymentsProvider =
    Provider<List<OfflinePaymentRecord>>((ref) {
  return ref
      .watch(offlinePaymentsProvider)
      .where((item) => item.status == OfflinePaymentStatus.bounced)
      .toList(growable: false);
});

final selectedOfflinePaymentsProvider =
    Provider<List<OfflinePaymentRecord>>((ref) {
  final tab = ref.watch(offlinePaymentsTabProvider);
  return switch (tab) {
    1 => ref.watch(reconciledOfflinePaymentsProvider),
    2 => ref.watch(bouncedOfflinePaymentsProvider),
    _ => ref.watch(pendingOfflinePaymentsProvider),
  };
});
