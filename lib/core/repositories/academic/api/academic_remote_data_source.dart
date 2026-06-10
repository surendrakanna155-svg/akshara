import 'package:dio/dio.dart';

import '../../repository_query.dart';
import 'academic_api_paths.dart';
import 'dto/academic_catalog_response_dto.dart';
import 'dto/academic_class_dto.dart';
import 'dto/academic_section_dto.dart';
import 'dto/academic_teacher_assignment_dto.dart';
import 'dto/academic_year_dto.dart';

/// Dio-backed remote data source for Academic catalog routes.
class AcademicRemoteDataSource {
  AcademicRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AcademicCatalogResponseDto<AcademicYearDto>> fetchYears({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AcademicApiPaths.years,
      queryParameters: _queryParams(query),
    );
    return AcademicCatalogResponseDto.years(_responseMap(response));
  }

  Future<AcademicCatalogResponseDto<AcademicClassDto>> fetchClasses({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AcademicApiPaths.classes,
      queryParameters: {
        ..._queryParams(query),
        if (academicYearId != null) 'academicYearId': academicYearId,
      },
    );
    return AcademicCatalogResponseDto.classes(_responseMap(response));
  }

  Future<AcademicCatalogResponseDto<AcademicSectionDto>> fetchSections({
    required RepositoryQuery query,
    String? classId,
    String? academicYearId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AcademicApiPaths.sections,
      queryParameters: {
        ..._queryParams(query),
        if (classId != null) 'classId': classId,
        if (academicYearId != null) 'academicYearId': academicYearId,
      },
    );
    return AcademicCatalogResponseDto.sections(_responseMap(response));
  }

  Future<AcademicCatalogResponseDto<AcademicTeacherAssignmentDto>>
      fetchTeacherAssignments({
    required RepositoryQuery query,
    String? classId,
    String? sectionId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AcademicApiPaths.teacherAssignments,
      queryParameters: {
        ..._queryParams(query),
        if (classId != null) 'classId': classId,
        if (sectionId != null) 'sectionId': sectionId,
      },
    );
    return AcademicCatalogResponseDto.teacherAssignments(_responseMap(response));
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
      ...query.paginationQueryParams(),
    };
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }
}
