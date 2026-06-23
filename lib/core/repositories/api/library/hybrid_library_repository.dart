import '../../interfaces/library_repository.dart';
import '../../mock/mock_library_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/library/library_models.dart';
import '../../../../features/library/library_requests.dart';
import 'api_library_repository.dart';
import '../hybrid_write_fallback.dart';

/// API reads with mock fallback for library write operations.
class HybridLibraryRepository implements LibraryRepository {
  HybridLibraryRepository({
    required ApiLibraryRepository api,
    required MockLibraryRepository mock,
  })  : _api = api,
        _mock = mock;

  final ApiLibraryRepository _api;
  final MockLibraryRepository _mock;

  @override
  Future<LibraryDashboardData> getDashboard({required RepositoryQuery query}) =>
      _api.getDashboard(query: query);

  @override
  Future<PaginatedResult<LibraryBook>> getCatalog({required RepositoryQuery query}) =>
      _api.getCatalog(query: query);

  @override
  Future<PaginatedResult<LibraryIssueRecord>> getIssues({
    required RepositoryQuery query,
  }) =>
      _api.getIssues(query: query);

  @override
  Future<PaginatedResult<LibraryReturnRecord>> getReturns({
    required RepositoryQuery query,
  }) =>
      _api.getReturns(query: query);

  @override
  Future<PaginatedResult<LibraryMember>> getMembers({
    required RepositoryQuery query,
  }) =>
      _api.getMembers(query: query);

  @override
  Future<LibraryFinesData> getFines({required RepositoryQuery query}) =>
      _api.getFines(query: query);

  @override
  Future<LibraryDigitalResourcesData> getDigitalResources({
    required RepositoryQuery query,
  }) =>
      _api.getDigitalResources(query: query);

  @override
  Future<LibraryReportsData> getReports({required RepositoryQuery query}) =>
      _api.getReports(query: query);

  @override
  Future<LibraryIssueRecord> issueLibraryBook({
    required RepositoryQuery query,
    required IssueLibraryBookRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.issueLibraryBook(query: query, request: request),
        mockCall: () => _mock.issueLibraryBook(query: query, request: request),
      );

  @override
  Future<LibraryReturnRecord> returnLibraryBook({
    required RepositoryQuery query,
    required ReturnLibraryBookRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.returnLibraryBook(query: query, request: request),
        mockCall: () => _mock.returnLibraryBook(query: query, request: request),
      );

  @override
  Future<LibraryBook> addLibraryBook({
    required RepositoryQuery query,
    required AddLibraryBookRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.addLibraryBook(query: query, request: request),
        mockCall: () => _mock.addLibraryBook(query: query, request: request),
      );

  @override
  Future<LibraryDigitalResource> addDigitalResource({
    required RepositoryQuery query,
    required AddLibraryResourceRequest request,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.addDigitalResource(query: query, request: request),
        mockCall: () => _mock.addDigitalResource(query: query, request: request),
      );
}

