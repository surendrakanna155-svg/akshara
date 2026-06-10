import '../../../../../features/sis/sis_requests.dart';
import '../../../academic/academic_catalog_placement.dart';

class AdmissionsConversionRequestDto {
  const AdmissionsConversionRequestDto({required this.raw});

  factory AdmissionsConversionRequestDto.fromDomain(
    AdmissionsConversionRequest request,
  ) {
    return AdmissionsConversionRequestDto(
      raw: {
        'enrollmentId': request.enrollmentId,
        'enrollment_id': request.enrollmentId,
        'academicYear': request.academicYear,
        'academic_year': request.academicYear,
        'className': request.classLabel,
        'class_name': request.classLabel,
        'classLabel': request.classLabel,
        'class_label': request.classLabel,
        'sectionName': request.section,
        'section_name': request.section,
        'section': request.section,
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
