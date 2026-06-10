import '../../../../../features/sis/sis_requests.dart';
import '../../../academic/academic_catalog_placement.dart';

class EnrollmentCreateRequestDto {
  const EnrollmentCreateRequestDto({required this.raw});

  factory EnrollmentCreateRequestDto.fromAcademicAssignment(
    AcademicAssignmentRequest request,
  ) {
    return EnrollmentCreateRequestDto(
      raw: {
        'studentId': request.studentId,
        'student_id': request.studentId,
        'academicYear': request.academicYear,
        'academic_year': request.academicYear,
        'className': request.classLabel,
        'class_name': request.classLabel,
        'classLabel': request.classLabel,
        'class_label': request.classLabel,
        'sectionName': request.section,
        'section_name': request.section,
        'section': request.section,
        'isCurrent': true,
        'is_current': true,
        ...catalogPlacementJson(
          AcademicCatalogPlacement(
            academicYearId: request.academicYearId,
            classId: request.classId,
            sectionId: request.sectionId,
          ),
        ),
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
