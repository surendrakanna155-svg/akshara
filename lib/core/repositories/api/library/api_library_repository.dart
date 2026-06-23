import '../api_exception.dart';
import '../../interfaces/library_repository.dart';
import '../../pagination_helpers.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/library/library_models.dart';
import '../../../../features/library/library_requests.dart';
import 'mapper/library_mapper.dart';
import 'remote/library_remote_datasource.dart';

/// API implementation of [LibraryRepository] — enabled via [libraryApiEnabledProvider].
class ApiLibraryRepository implements LibraryRepository {
  ApiLibraryRepository({
    required LibraryRemoteDataSource remote,
    LibraryMapper mapper = const LibraryMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final LibraryRemoteDataSource _remote;
  final LibraryMapper _mapper;

  @override
  Future<LibraryDashboardData> getDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<PaginatedResult<LibraryBook>> getCatalog({required RepositoryQuery query}) async {
    final dto = await _remote.fetchCatalog(query: query);
    return paginateList(_mapper.toCatalog(dto), query);
  }

  @override
  Future<PaginatedResult<LibraryIssueRecord>> getIssues({required RepositoryQuery query}) async {
    final dto = await _remote.fetchIssues(query: query);
    return paginateList(_mapper.toIssues(dto), query);
  }

  @override
  Future<PaginatedResult<LibraryReturnRecord>> getReturns({required RepositoryQuery query}) async {
    final dto = await _remote.fetchReturns(query: query);
    return paginateList(_mapper.toReturns(dto), query);
  }

  @override
  Future<PaginatedResult<LibraryMember>> getMembers({required RepositoryQuery query}) async {
    final dto = await _remote.fetchMembers(query: query);
    return paginateList(_mapper.toMembers(dto), query);
  }

  @override
  Future<LibraryFinesData> getFines({required RepositoryQuery query}) async {
    final dto = await _remote.fetchFines(query: query);
    return _mapper.toFines(dto);
  }

  @override
  Future<LibraryDigitalResourcesData> getDigitalResources({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchDigitalResources(query: query);
    return _mapper.toDigitalResources(dto);
  }

  @override
  Future<LibraryReportsData> getReports({required RepositoryQuery query}) async {
    final dto = await _remote.fetchReports(query: query);
    return _mapper.toReports(dto);
  }

  @override
  Future<LibraryIssueRecord> issueLibraryBook({
    required RepositoryQuery query,
    required IssueLibraryBookRequest request,
  }) async {
    throw ApiNotConnectedException('LibraryRepository', 'issueLibraryBook');
  }

  @override
  Future<LibraryReturnRecord> returnLibraryBook({
    required RepositoryQuery query,
    required ReturnLibraryBookRequest request,
  }) async {
    throw ApiNotConnectedException('LibraryRepository', 'returnLibraryBook');
  }

  @override
  Future<LibraryBook> addLibraryBook({
    required RepositoryQuery query,
    required AddLibraryBookRequest request,
  }) async {
    throw ApiNotConnectedException('LibraryRepository', 'addLibraryBook');
  }

  @override
  Future<LibraryDigitalResource> addDigitalResource({
    required RepositoryQuery query,
    required AddLibraryResourceRequest request,
  }) async {
    throw ApiNotConnectedException('LibraryRepository', 'addDigitalResource');
  }
}
