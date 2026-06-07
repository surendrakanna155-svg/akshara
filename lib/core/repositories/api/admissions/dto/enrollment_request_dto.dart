import '../../../../../features/admissions/admissions_requests.dart';

class EnrollmentRequestDto {
  const EnrollmentRequestDto({required this.raw});

  factory EnrollmentRequestDto.submit(EnrollmentSubmitRequest request) {
    return EnrollmentRequestDto(
      raw: {
        if (request.applicationId != null)
          'application_id': request.applicationId,
        'student': {
          'full_name': request.student.fullName,
          'date_of_birth': request.student.dateOfBirth,
          'gender': request.student.gender,
          'aadhaar': request.student.aadhaar,
        },
        'parent': {
          'guardian_name': request.parent.guardianName,
          'relationship': request.parent.relationship,
          'phone': request.parent.phone,
          'email': request.parent.email,
          'address': request.parent.address,
        },
        'academic': {
          'seeking_class': request.academic.seekingClass,
          'section': request.academic.section,
          'academic_year': request.academic.academicYear,
          'previous_school': request.academic.previousSchool,
          'needs_transport': request.academic.needsTransport,
          'needs_hostel': request.academic.needsHostel,
        },
      },
    );
  }

  factory EnrollmentRequestDto.generateNumber(
    GenerateAdmissionNumberRequest request,
  ) {
    return EnrollmentRequestDto(
      raw: {
        if (request.enrollmentId != null) 'enrollment_id': request.enrollmentId,
        if (request.applicationId != null)
          'application_id': request.applicationId,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class GeneratedAdmissionNumberDto {
  const GeneratedAdmissionNumberDto({required this.raw});

  factory GeneratedAdmissionNumberDto.fromJson(Map<String, dynamic> json) {
    final envelope = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return GeneratedAdmissionNumberDto(raw: envelope);
  }

  final Map<String, dynamic> raw;

  String get admissionNumber =>
      raw['admission_number'] as String? ??
      raw['admissionNumber'] as String? ??
      '';
}
