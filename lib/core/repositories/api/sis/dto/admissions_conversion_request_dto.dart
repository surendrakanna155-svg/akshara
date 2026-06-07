import '../../../../../features/sis/sis_requests.dart';

class AdmissionsConversionRequestDto {
  const AdmissionsConversionRequestDto({required this.raw});

  factory AdmissionsConversionRequestDto.fromDomain(
    AdmissionsConversionRequest request,
  ) {
    return AdmissionsConversionRequestDto(
      raw: {
        'enrollment_id': request.enrollmentId,
        'class_label': request.classLabel,
        'section': request.section,
        'academic_year': request.academicYear,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class SisConversionPreviewDto {
  const SisConversionPreviewDto({required this.raw});

  factory SisConversionPreviewDto.fromJson(Map<String, dynamic> json) {
    return SisConversionPreviewDto(raw: json);
  }

  final Map<String, dynamic> raw;
}
