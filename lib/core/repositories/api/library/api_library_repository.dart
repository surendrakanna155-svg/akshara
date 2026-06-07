// ignore_for_file: unused_field
import '../api_exception.dart';
import '../../repository_query.dart';
import '../../interfaces/library_repository.dart';
import '../../../../features/library/library_models.dart';
import 'mapper/library_mapper.dart';
import 'remote/library_remote_datasource.dart';

/// API implementation of [LibraryRepository] — swap via [useApiRepositoriesProvider].
class ApiLibraryRepository implements LibraryRepository {
  ApiLibraryRepository({
    required LibraryRemoteDataSource remote,
    LibraryMapper mapper = const LibraryMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final LibraryRemoteDataSource _remote;
  final LibraryMapper _mapper;

  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApiLibraryRepository', method);
  }

  @override
  Future<LibraryDashboardData> getDashboard({required RepositoryQuery query}) async => _notConnected('getDashboard');

  @override
  Future<List<LibraryBook>> getCatalog({required RepositoryQuery query}) async => _notConnected('getCatalog');

  @override
  Future<List<LibraryIssueRecord>> getIssues({required RepositoryQuery query}) async => _notConnected('getIssues');

  @override
  Future<List<LibraryReturnRecord>> getReturns({required RepositoryQuery query}) async => _notConnected('getReturns');

  @override
  Future<List<LibraryMember>> getMembers({required RepositoryQuery query}) async => _notConnected('getMembers');

  @override
  Future<LibraryFinesData> getFines({required RepositoryQuery query}) async => _notConnected('getFines');

  @override
  Future<LibraryDigitalResourcesData> getDigitalResources({required RepositoryQuery query}) async => _notConnected('getDigitalResources');

  @override
  Future<LibraryReportsData> getReports({required RepositoryQuery query}) async => _notConnected('getReports');
}
