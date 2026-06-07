import '../../../../../features/sis/sis_requests.dart';

class UpdateStudentRequestDto {
  const UpdateStudentRequestDto({required this.raw});

  factory UpdateStudentRequestDto.fromDomain(UpdateStudentRequest request) {
    return UpdateStudentRequestDto(
      raw: {
        if (request.studentName != null) 'student_name': request.studentName,
        if (request.admissionNumber != null)
          'admission_number': request.admissionNumber,
        if (request.classLabel != null) 'class_label': request.classLabel,
        if (request.section != null) 'section': request.section,
        if (request.academicYear != null) 'academic_year': request.academicYear,
        if (request.gender != null) 'gender': request.gender,
        if (request.dateOfBirth != null) 'date_of_birth': request.dateOfBirth,
        if (request.guardianName != null) 'guardian_name': request.guardianName,
        if (request.phone != null) 'phone': request.phone,
        if (request.email != null) 'email': request.email,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
