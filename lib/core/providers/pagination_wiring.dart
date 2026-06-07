import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/paginated_result.dart';
import '../repositories/repository_query.dart';
import '../tenant/tenant_provider.dart';
import 'repository_future.dart';

/// Wires page-scoped query + page result providers for a paginated list endpoint.
class PaginatedListWiring<T> {
  PaginatedListWiring({
    required this.pageProvider,
    required this.queryProvider,
    required this.pageResultProvider,
  });

  final StateProvider<int> pageProvider;
  final Provider<RepositoryQuery> queryProvider;
  final Provider<PaginatedResult<T>?> pageResultProvider;
}

PaginatedListWiring<T> wirePaginatedList<T>({
  required StateProvider<int> pageProvider,
  required StateProvider<bool> loadingProvider,
  required StateProvider<bool> errorProvider,
  required StateProvider<bool> emptyProvider,
  required FutureProvider<PaginatedResult<T>> futureProvider,
}) {
  final queryProvider = Provider<RepositoryQuery>((ref) {
    final baseQuery = ref.watch(repositoryQueryProvider);
    final page = ref.watch(pageProvider);
    return baseQuery.withPage(page);
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

  return PaginatedListWiring(
    pageProvider: pageProvider,
    queryProvider: queryProvider,
    pageResultProvider: pageResultProvider,
  );
}
