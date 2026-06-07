import '../../../../../features/sis/sis_requests.dart';

class AcademicAssignmentRequestDto {
  const AcademicAssignmentRequestDto({required this.raw});

  factory AcademicAssignmentRequestDto.fromDomain(
    AcademicAssignmentRequest request,
  ) {
    return AcademicAssignmentRequestDto(
      raw: {
        'student_id': request.studentId,
        'class_label': request.classLabel,
        'section': request.section,
        'academic_year': request.academicYear,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
