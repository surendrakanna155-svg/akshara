import '../../../api/admissions/dto/api_envelope_dto.dart';
import '../../../api/admissions/dto/pagination_dto.dart';
import 'academic_class_dto.dart';
import 'academic_section_dto.dart';
import 'academic_teacher_assignment_dto.dart';
import 'academic_year_dto.dart';

/// Parses `{ data: { items, pagination } }` list envelopes for Academic routes.
class AcademicCatalogResponseDto<T> {
  const AcademicCatalogResponseDto({
    required this.items,
    this.pagination,
  });

  static AcademicCatalogResponseDto<AcademicYearDto> years(
    Map<String, dynamic> json,
  ) {
    return _parse(json, AcademicYearDto.fromJson);
  }

  static AcademicCatalogResponseDto<AcademicClassDto> classes(
    Map<String, dynamic> json,
  ) {
    return _parse(json, AcademicClassDto.fromJson);
  }

  static AcademicCatalogResponseDto<AcademicSectionDto> sections(
    Map<String, dynamic> json,
  ) {
    return _parse(json, AcademicSectionDto.fromJson);
  }

  static AcademicCatalogResponseDto<AcademicTeacherAssignmentDto>
      teacherAssignments(
    Map<String, dynamic> json,
  ) {
    return _parse(json, AcademicTeacherAssignmentDto.fromJson);
  }

  static AcademicCatalogResponseDto<R> _parse<R>(
    Map<String, dynamic> json,
    R Function(Map<String, dynamic>) parseItem,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    final listItems = envelope.requireListItems();
    return AcademicCatalogResponseDto(
      items: [for (final item in listItems) parseItem(item)],
      pagination: envelope.pagination,
    );
  }

  final List<T> items;
  final PaginationDto? pagination;
}
