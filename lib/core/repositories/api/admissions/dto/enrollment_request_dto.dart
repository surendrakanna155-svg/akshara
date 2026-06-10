import '../../../../../features/admissions/admissions_requests.dart';
import '../../../academic/academic_catalog_placement.dart';

class EnrollmentRequestDto {
  const EnrollmentRequestDto({required this.raw});

  factory EnrollmentRequestDto.submit(EnrollmentSubmitRequest request) {
    final academic = request.academic;
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
          'seeking_class': academic.seekingClass,
          'section': academic.section,
          'academic_year': academic.academicYear,
          'previous_school': academic.previousSchool,
          'needs_transport': academic.needsTransport,
          'needs_hostel': academic.needsHostel,
          ...catalogPlacementJson(
            AcademicCatalogPlacement(
              academicYearId: academic.academicYearId,
              classId: academic.classId,
              sectionId: academic.sectionId,
            ),
          ),
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
