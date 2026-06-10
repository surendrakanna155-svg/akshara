import '../../../../../features/sis/sis_requests.dart';
import 'sis_enum_codec.dart';

class CreateStudentRequestDto {
  const CreateStudentRequestDto({required this.raw});

  factory CreateStudentRequestDto.fromDomain(CreateStudentRequest request) {
    return CreateStudentRequestDto(
      raw: {
        'displayName': request.studentName,
        'display_name': request.studentName,
        'studentName': request.studentName,
        'student_name': request.studentName,
        'admissionNumber': request.admissionNumber,
        'admission_number': request.admissionNumber,
        'dateOfBirth': request.dateOfBirth,
        'date_of_birth': request.dateOfBirth,
        'gender': request.gender,
        'status': SisEnumCodec.studentStatusToApi(request.status),
        if (request.guardianName.isNotEmpty) 'guardianName': request.guardianName,
        if (request.phone.isNotEmpty) 'phone': request.phone,
        if (request.email.isNotEmpty) 'email': request.email,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
