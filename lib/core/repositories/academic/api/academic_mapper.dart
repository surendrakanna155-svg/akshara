import '../academic_models.dart';
import '../academic_year_label.dart';
import 'dto/academic_class_dto.dart';
import 'dto/academic_section_dto.dart';
import 'dto/academic_teacher_assignment_dto.dart';
import 'dto/academic_year_dto.dart';

class AcademicMapper {
  const AcademicMapper();

  AcademicYear toYear(AcademicYearDto dto) {
    return AcademicYear(
      yearId: dto.yearId,
      yearLabel: normalizeAcademicYearLabel(dto.yearLabel),
      startDate: dto.startDate,
      endDate: dto.endDate,
      isCurrent: dto.isCurrent,
      status: dto.status,
    );
  }

  AcademicClass toClass(AcademicClassDto dto) {
    return AcademicClass(
      classId: dto.classId,
      academicYearId: dto.academicYearId,
      className: dto.className,
      displayOrder: dto.displayOrder,
      status: dto.status,
    );
  }

  AcademicSection toSection(AcademicSectionDto dto) {
    return AcademicSection(
      sectionId: dto.sectionId,
      classId: dto.classId,
      className: dto.className,
      sectionName: dto.sectionName,
      capacity: dto.capacity,
      strength: dto.strength,
      status: dto.status,
    );
  }

  AcademicTeacherAssignment toTeacherAssignment(
    AcademicTeacherAssignmentDto dto,
  ) {
    return AcademicTeacherAssignment(
      assignmentId: dto.assignmentId,
      teacherId: dto.teacherId,
      teacherName: dto.teacherName,
      classId: dto.classId,
      className: dto.className,
      sectionId: dto.sectionId,
      sectionName: dto.sectionName,
      role: dto.role,
      isPrimary: dto.isPrimary,
    );
  }

  List<AcademicYear> toYears(List<AcademicYearDto> dtos) =>
      [for (final dto in dtos) toYear(dto)];

  List<AcademicClass> toClasses(List<AcademicClassDto> dtos) =>
      [for (final dto in dtos) toClass(dto)];

  List<AcademicSection> toSections(List<AcademicSectionDto> dtos) =>
      [for (final dto in dtos) toSection(dto)];

  List<AcademicTeacherAssignment> toTeacherAssignments(
    List<AcademicTeacherAssignmentDto> dtos,
  ) => [for (final dto in dtos) toTeacherAssignment(dto)];
}
