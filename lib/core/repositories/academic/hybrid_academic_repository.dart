import '../paginated_result.dart';
import '../repository_query.dart';
import 'academic_models.dart';
import 'academic_repository.dart';
import 'api/api_academic_repository.dart';

/// Routes academic catalog reads to [ApiAcademicRepository].
class HybridAcademicRepository implements AcademicRepository {
  HybridAcademicRepository({required ApiAcademicRepository api}) : _api = api;

  final ApiAcademicRepository _api;

  @override
  Future<PaginatedResult<AcademicYear>> getYears({
    required RepositoryQuery query,
  }) =>
      _api.getYears(query: query);

  @override
  Future<PaginatedResult<AcademicClass>> getClasses({
    required RepositoryQuery query,
    String? academicYearId,
  }) =>
      _api.getClasses(query: query, academicYearId: academicYearId);

  @override
  Future<PaginatedResult<AcademicSection>> getSections({
    required RepositoryQuery query,
    String? classId,
    String? academicYearId,
  }) =>
      _api.getSections(
        query: query,
        classId: classId,
        academicYearId: academicYearId,
      );

  @override
  Future<PaginatedResult<AcademicTeacherAssignment>> getTeacherAssignments({
    required RepositoryQuery query,
    String? classId,
    String? sectionId,
  }) =>
      _api.getTeacherAssignments(
        query: query,
        classId: classId,
        sectionId: sectionId,
      );
}
