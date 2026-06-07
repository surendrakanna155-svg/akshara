import '../../../../../features/admissions/admissions_requests.dart';

class ApplicationRequestDto {
  const ApplicationRequestDto({required this.raw});

  factory ApplicationRequestDto.create(CreateApplicationRequest request) {
    return ApplicationRequestDto(
      raw: {
        'student_name': request.studentName,
        'class_label': request.classLabel,
        'parent_name': request.parentName,
        if (request.leadId != null) 'lead_id': request.leadId,
        'counselor': request.counselor,
      },
    );
  }

  factory ApplicationRequestDto.update(UpdateApplicationRequest request) {
    return ApplicationRequestDto(
      raw: {
        if (request.studentName != null) 'student_name': request.studentName,
        if (request.classLabel != null) 'class_label': request.classLabel,
        if (request.parentName != null) 'parent_name': request.parentName,
        if (request.counselor != null) 'counselor': request.counselor,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
