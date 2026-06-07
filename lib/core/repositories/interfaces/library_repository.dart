import '../../../features/library/library_models.dart';
import '../repository_query.dart';

/// Contract for library data access (mock or API).
abstract class LibraryRepository {
  Future<LibraryDashboardData> getDashboard({required RepositoryQuery query});
  Future<List<LibraryBook>> getCatalog({required RepositoryQuery query});
  Future<List<LibraryIssueRecord>> getIssues({required RepositoryQuery query});
  Future<List<LibraryReturnRecord>> getReturns({required RepositoryQuery query});
  Future<List<LibraryMember>> getMembers({required RepositoryQuery query});
  Future<LibraryFinesData> getFines({required RepositoryQuery query});
  Future<LibraryDigitalResourcesData> getDigitalResources({required RepositoryQuery query});
  Future<LibraryReportsData> getReports({required RepositoryQuery query});
}
