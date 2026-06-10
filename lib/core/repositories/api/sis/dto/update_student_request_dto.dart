import '../../../../../features/sis/sis_requests.dart';

class UpdateStudentRequestDto {
  const UpdateStudentRequestDto({required this.raw});

  factory UpdateStudentRequestDto.fromDomain(UpdateStudentRequest request) {
    return UpdateStudentRequestDto(
      raw: {
        if (request.studentName != null) ...{
          'displayName': request.studentName,
          'display_name': request.studentName,
          'studentName': request.studentName,
          'student_name': request.studentName,
        },
        if (request.admissionNumber != null) ...{
          'admissionNumber': request.admissionNumber,
          'admission_number': request.admissionNumber,
        },
        if (request.gender != null) 'gender': request.gender,
        if (request.dateOfBirth != null) ...{
          'dateOfBirth': request.dateOfBirth,
          'date_of_birth': request.dateOfBirth,
        },
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
