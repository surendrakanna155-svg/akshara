import '../../../../../features/sis/sis_requests.dart';
import 'sis_enum_codec.dart';

class CreateStudentRequestDto {
  const CreateStudentRequestDto({required this.raw});

  factory CreateStudentRequestDto.fromDomain(CreateStudentRequest request) {
    return CreateStudentRequestDto(
      raw: {
        'student_name': request.studentName,
        'admission_number': request.admissionNumber,
        'class_label': request.classLabel,
        'section': request.section,
        'academic_year': request.academicYear,
        'status': SisEnumCodec.studentStatusToApi(request.status),
        'gender': request.gender,
        'date_of_birth': request.dateOfBirth,
        'guardian_name': request.guardianName,
        'phone': request.phone,
        'email': request.email,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
