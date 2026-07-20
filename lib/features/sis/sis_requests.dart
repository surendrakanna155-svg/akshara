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

/// Domain request to confirm a student document upload.
///
/// PRA-P1-19: [storagePath] is the tenant-prefixed path of the object the client
/// already PUT to Storage via the presign step. The backend refuses to persist a
/// document without it (no more fabricated `storage://documents/<name>` rows).
class UploadStudentDocumentRequest {
  const UploadStudentDocumentRequest({
    required this.type,
    required this.fileName,
    this.status = 'Pending',
    this.storagePath,
  });

  final String type;
  final String fileName;
  final String status;
  final String? storagePath;
}

/// SIS-3 — the two allowed review outcomes for a pending student document.
enum SisDocumentDecision { verified, rejected }

/// Domain request to verify or reject a student document (SIS-3).
class VerifyStudentDocumentRequest {
  const VerifyStudentDocumentRequest({
    required this.decision,
    this.note,
  });

  final SisDocumentDecision decision;

  /// Optional reviewer note (e.g. rejection reason).
  final String? note;
}

/// SIS-1 — domain request to issue a bonafide/study/conduct certificate.
class IssueCertificateRequest {
  const IssueCertificateRequest({
    required this.type,
    this.reason,
  });

  final SisCertificateType type;

  /// Optional free-text reason (e.g. "for bank account opening").
  final String? reason;
}

/// SIS-D1 — domain request to issue a Transfer Certificate (TC). No type: the
/// TC engine is dedicated. `reason` is optional.
class IssueTransferCertificateRequest {
  const IssueTransferCertificateRequest({this.reason});

  final String? reason;
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

/// Domain request to assign many students to the same class, section, and
/// academic year in a single operation.
class BulkAcademicAssignmentRequest {
  const BulkAcademicAssignmentRequest({
    required this.studentIds,
    required this.classLabel,
    required this.section,
    required this.academicYear,
  });

  final List<String> studentIds;
  final String classLabel;
  final String section;
  final String academicYear;
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
