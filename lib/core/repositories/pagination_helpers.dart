import 'paginated_result.dart';
import 'repository_query.dart';

/// Wraps a full in-memory list as a paginated slice for mock/API fallback.
PaginatedResult<T> paginateList<T>(
  List<T> allItems,
  RepositoryQuery query,
) {
  return PaginatedResult.fromItems(
    allItems,
    page: query.page,
    pageSize: query.pageSize,
  );
}
