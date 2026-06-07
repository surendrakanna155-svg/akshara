import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/paginated_result.dart';
import '../repositories/repository_query.dart';
import '../tenant/tenant_provider.dart';
import '../../shared/async/erp_async_state.dart';
import 'repository_future.dart';

/// Creates standard pagination providers for a repository list endpoint.
PaginatedListBundle<T> createPaginatedListProviders<T>({
  required StateProvider<int> pageProvider,
  required Future<PaginatedResult<T>> Function(Ref ref, RepositoryQuery query)
      fetch,
  required StateProvider<bool> loadingProvider,
  required StateProvider<bool> errorProvider,
  required StateProvider<bool> emptyProvider,
}) {
  final queryProvider = Provider<RepositoryQuery>((ref) {
    final baseQuery = ref.watch(repositoryQueryProvider);
    final page = ref.watch(pageProvider);
    return baseQuery.withPage(page);
  });

  final futureProvider = FutureProvider<PaginatedResult<T>>((ref) async {
    return fetch(ref, ref.watch(queryProvider));
  });

  final pageResultProvider = Provider<PaginatedResult<T>?>((ref) {
    return watchRepositoryFuture(
      ref,
      ref.watch(futureProvider),
      manualLoading: ref.watch(loadingProvider),
      manualError: ref.watch(errorProvider),
      manualEmpty: ref.watch(emptyProvider),
    );
  });

  final itemsProvider = Provider<List<T>>((ref) {
    return ref.watch(pageResultProvider)?.items ?? const [];
  });

  final viewStateProvider =
      Provider<ErpViewState<PaginatedResult<T>>>((ref) {
    return resolveErpAsync(
      ref.watch(futureProvider),
      forceLoading: ref.watch(loadingProvider),
      forceError: ref.watch(errorProvider),
      forceEmpty: ref.watch(emptyProvider),
      isDataEmpty: (result) => result.items.isEmpty,
    );
  });

  return PaginatedListBundle(
    queryProvider: queryProvider,
    futureProvider: futureProvider,
    pageResultProvider: pageResultProvider,
    itemsProvider: itemsProvider,
    viewStateProvider: viewStateProvider,
  );
}

class PaginatedListBundle<T> {
  const PaginatedListBundle({
    required this.queryProvider,
    required this.futureProvider,
    required this.pageResultProvider,
    required this.itemsProvider,
    required this.viewStateProvider,
  });

  final Provider<RepositoryQuery> queryProvider;
  final FutureProvider<PaginatedResult<T>> futureProvider;
  final Provider<PaginatedResult<T>?> pageResultProvider;
  final Provider<List<T>> itemsProvider;
  final Provider<ErpViewState<PaginatedResult<T>>> viewStateProvider;
}
