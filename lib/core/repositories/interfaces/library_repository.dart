import '../../../features/library/library_models.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for library data access (mock or API).
abstract class LibraryRepository {
  Future<LibraryDashboardData> getDashboard({required RepositoryQuery query});
  Future<PaginatedResult<LibraryBook>> getCatalog({required RepositoryQuery query});
  Future<PaginatedResult<LibraryIssueRecord>> getIssues({required RepositoryQuery query});
  Future<PaginatedResult<LibraryReturnRecord>> getReturns({required RepositoryQuery query});
  Future<PaginatedResult<LibraryMember>> getMembers({required RepositoryQuery query});
  Future<LibraryFinesData> getFines({required RepositoryQuery query});
  Future<LibraryDigitalResourcesData> getDigitalResources({required RepositoryQuery query});
  Future<LibraryReportsData> getReports({required RepositoryQuery query});
}
