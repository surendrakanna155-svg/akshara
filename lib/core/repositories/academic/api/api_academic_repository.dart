import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../academic_models.dart';
import '../academic_repository.dart';
import 'academic_mapper.dart';
import 'academic_remote_data_source.dart';

/// API implementation of [AcademicRepository] — enabled via [academicApiEnabledProvider].
class ApiAcademicRepository implements AcademicRepository {
  ApiAcademicRepository({
    required AcademicRemoteDataSource remote,
    AcademicMapper mapper = const AcademicMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final AcademicRemoteDataSource _remote;
  final AcademicMapper _mapper;

  @override
  Future<PaginatedResult<AcademicYear>> getYears({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchYears(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toYears(dto.items),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<PaginatedResult<AcademicClass>> getClasses({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    final dto = await _remote.fetchClasses(
      query: query,
      academicYearId: academicYearId,
    );
    return PaginatedResult.fromDto(
      items: _mapper.toClasses(dto.items),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<PaginatedResult<AcademicSection>> getSections({
    required RepositoryQuery query,
    String? classId,
    String? academicYearId,
  }) async {
    final dto = await _remote.fetchSections(
      query: query,
      classId: classId,
      academicYearId: academicYearId,
    );
    return PaginatedResult.fromDto(
      items: _mapper.toSections(dto.items),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<PaginatedResult<AcademicTeacherAssignment>> getTeacherAssignments({
    required RepositoryQuery query,
    String? classId,
    String? sectionId,
  }) async {
    final dto = await _remote.fetchTeacherAssignments(
      query: query,
      classId: classId,
      sectionId: sectionId,
    );
    return PaginatedResult.fromDto(
      items: _mapper.toTeacherAssignments(dto.items),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }
}
