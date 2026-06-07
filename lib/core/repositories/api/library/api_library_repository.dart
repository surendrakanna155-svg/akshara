import '../../interfaces/library_repository.dart';
import '../../repository_query.dart';
import '../../../../features/library/library_models.dart';
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
  Future<List<LibraryBook>> getCatalog({required RepositoryQuery query}) async {
    final dto = await _remote.fetchCatalog(query: query);
    return _mapper.toCatalog(dto);
  }

  @override
  Future<List<LibraryIssueRecord>> getIssues({required RepositoryQuery query}) async {
    final dto = await _remote.fetchIssues(query: query);
    return _mapper.toIssues(dto);
  }

  @override
  Future<List<LibraryReturnRecord>> getReturns({required RepositoryQuery query}) async {
    final dto = await _remote.fetchReturns(query: query);
    return _mapper.toReturns(dto);
  }

  @override
  Future<List<LibraryMember>> getMembers({required RepositoryQuery query}) async {
    final dto = await _remote.fetchMembers(query: query);
    return _mapper.toMembers(dto);
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
}
