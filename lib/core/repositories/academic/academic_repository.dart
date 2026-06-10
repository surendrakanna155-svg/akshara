import '../paginated_result.dart';
import '../repository_query.dart';
import 'academic_models.dart';

/// Read-only academic catalog repository — years, classes, sections, teachers.
abstract class AcademicRepository {
  Future<PaginatedResult<AcademicYear>> getYears({
    required RepositoryQuery query,
  });

  Future<PaginatedResult<AcademicClass>> getClasses({
    required RepositoryQuery query,
    String? academicYearId,
  });

  Future<PaginatedResult<AcademicSection>> getSections({
    required RepositoryQuery query,
    String? classId,
    String? academicYearId,
  });

  Future<PaginatedResult<AcademicTeacherAssignment>> getTeacherAssignments({
    required RepositoryQuery query,
    String? classId,
    String? sectionId,
  });
}
