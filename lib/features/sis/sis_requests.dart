import 'sis_models.dart';

/// Domain request to register a new SIS student.
class CreateStudentRequest {
  const CreateStudentRequest({
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.section,
    required this.academicYear,
    this.status = SisStudentStatus.prospect,
    this.gender = '',
    this.dateOfBirth = '',
    this.guardianName = '',
    this.phone = '',
    this.email = '',
  });

  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String section;
  final String academicYear;
  final SisStudentStatus status;
  final String gender;
  final String dateOfBirth;
  final String guardianName;
  final String phone;
  final String email;
}

/// Domain request to update an existing student profile.
class UpdateStudentRequest {
  const UpdateStudentRequest({
    this.studentName,
    this.admissionNumber,
    this.classLabel,
    this.section,
    this.academicYear,
    this.gender,
    this.dateOfBirth,
    this.guardianName,
    this.phone,
    this.email,
  });

  final String? studentName;
  final String? admissionNumber;
  final String? classLabel;
  final String? section;
  final String? academicYear;
  final String? gender;
  final String? dateOfBirth;
  final String? guardianName;
  final String? phone;
  final String? email;
}

/// Domain request to upload a student document metadata record.
class UploadStudentDocumentRequest {
  const UploadStudentDocumentRequest({
    required this.type,
    required this.fileName,
    this.status = 'Pending',
  });

  final String type;
  final String fileName;
  final String status;
}

/// Domain request to change a student's lifecycle status.
class UpdateStudentStatusRequest {
  const UpdateStudentStatusRequest({required this.status});

  final SisStudentStatus status;
}

/// Domain request to assign class, section, and academic year.
class AcademicAssignmentRequest {
  const AcademicAssignmentRequest({
    required this.studentId,
    required this.classLabel,
    required this.section,
    required this.academicYear,
    this.academicYearId,
    this.classId,
    this.sectionId,
  });

  final String studentId;
  final String classLabel;
  final String section;
  final String academicYear;
  final String? academicYearId;
  final String? classId;
  final String? sectionId;
}

/// Domain request to convert an admissions enrollment into a SIS student.
class AdmissionsConversionRequest {
  const AdmissionsConversionRequest({
    required this.enrollmentId,
    required this.classLabel,
    required this.section,
    required this.academicYear,
    this.academicYearId,
    this.classId,
    this.sectionId,
  });

  final String enrollmentId;
  final String classLabel;
  final String section;
  final String academicYear;
  final String? academicYearId;
  final String? classId;
  final String? sectionId;
}
