import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/repositories/repository_providers.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeStudentAccountsLoadingProvider = StateProvider<bool>((ref) => false);
final financeStudentAccountsErrorProvider = StateProvider<bool>((ref) => false);
final financeStudentAccountsEmptyProvider = StateProvider<bool>((ref) => false);
final financeStudentSearchQueryProvider = StateProvider<String>((ref) => '');
final financeSelectedAccountIdProvider = StateProvider<String?>((ref) => null);
final financeStudentAccountsPageProvider = StateProvider<int>((ref) => 1);

final financeStudentAccountsQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(financeStudentAccountsPageProvider);
  return baseQuery.withPage(page);
});

final financeStudentAccountsFutureProvider =
    FutureProvider<PaginatedResult<StudentFeeAccount>>((ref) async {
  return ref.read(financeRepositoryProvider).getStudentAccounts(
        query: ref.watch(financeStudentAccountsQueryProvider),
      );
});

final financeStudentAccountsPageResultProvider =
    Provider<PaginatedResult<StudentFeeAccount>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(financeStudentAccountsFutureProvider),
    manualLoading: ref.watch(financeStudentAccountsLoadingProvider),
    manualError: ref.watch(financeStudentAccountsErrorProvider),
    manualEmpty: ref.watch(financeStudentAccountsEmptyProvider),
  );
});

final financeStudentAccountsProvider = Provider<List<StudentFeeAccount>>((ref) {
  return ref.watch(financeStudentAccountsPageResultProvider)?.items ?? const [];
});

final financeStudentAccountsViewStateProvider =
    Provider<FinanceViewState<PaginatedResult<StudentFeeAccount>>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeStudentAccountsFutureProvider),
    forceLoading: ref.watch(financeStudentAccountsLoadingProvider),
    forceError: ref.watch(financeStudentAccountsErrorProvider),
    forceEmpty: ref.watch(financeStudentAccountsEmptyProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});

final financeFilteredStudentAccountsProvider =
    Provider<List<StudentFeeAccount>>((ref) {
  final accounts = ref.watch(financeStudentAccountsProvider);
  final query = ref.watch(financeStudentSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return accounts;
  return accounts
      .where(
        (a) =>
            a.studentName.toLowerCase().contains(query) ||
            a.admissionNumber.toLowerCase().contains(query),
      )
      .toList(growable: false);
});

final financeSelectedStudentAccountProvider = Provider<StudentFeeAccount?>(
  (ref) {
    final accounts = ref.watch(financeFilteredStudentAccountsProvider);
    final selectedId = ref.watch(financeSelectedAccountIdProvider);
    if (selectedId != null) {
      for (final account in accounts) {
        if (account.id == selectedId) return account;
      }
    }
    return accounts.isEmpty ? null : accounts.first;
  },
);
