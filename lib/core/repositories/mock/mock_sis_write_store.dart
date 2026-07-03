import '../../../features/admissions/admissions_models.dart';
import '../../../features/sis/sis_models.dart';

/// Mutable in-memory store backing mock SIS write operations.
class MockSisWriteStore {
  MockSisWriteStore._();

  static final MockSisWriteStore instance = MockSisWriteStore._();

  List<SisStudent>? students;
  List<SisEnrollmentQueueItem>? conversionQueue;
  Map<String, List<SisDocumentSummary>>? studentDocuments;

  /// SIS-1 — per-student certificate issuance register (newest first).
  final Map<String, List<SisCertificateIssue>> certificates = {};

  int _studentSeq = 430;
  int _documentSeq = 900;
  int _certificateSeq = 700;

  /// Per-school running TC serial (mirrors the backend's sequential allocator).
  int _tcSeq = 0;

  String nextStudentId() => 'SIS-STU-10${++_studentSeq}';
  String nextDocumentId() => 'SIS-DOC-${++_documentSeq}';
  String nextCertificateId() => 'SIS-CERT-${++_certificateSeq}';

  /// Allocates the next zero-padded TC serial (never reused within a session).
  String nextTcSerial(String schoolCode, String academicYear) {
    final seq = ++_tcSeq;
    final year =
        academicYear.trim().isEmpty ? '$_tcSeq' : academicYear.trim();
    final code = schoolCode.trim().isEmpty ? 'SCH' : schoolCode.trim();
    return 'TC/$code/$year/${seq.toString().padLeft(4, '0')}';
  }

  List<SisCertificateIssue> certificatesForStudent(String studentId) {
    return certificates.putIfAbsent(studentId, () => <SisCertificateIssue>[]);
  }

  SisStudent? findStudent(String id) {
    return students?.cast<SisStudent?>().firstWhere(
          (student) => student?.id == id,
          orElse: () => null,
        );
  }

  SisEnrollmentQueueItem? findConversionItem(String enrollmentId) {
    return conversionQueue?.cast<SisEnrollmentQueueItem?>().firstWhere(
          (item) => item?.enrollment.id == enrollmentId,
          orElse: () => null,
        );
  }

  List<SisDocumentSummary> documentsForStudent(String studentId) {
    studentDocuments ??= <String, List<SisDocumentSummary>>{};
    return studentDocuments!
        .putIfAbsent(studentId, () => <SisDocumentSummary>[]);
  }

  SisStudent copyStudent(
    SisStudent student, {
    String? studentName,
    String? admissionNumber,
    String? classLabel,
    String? section,
    String? academicYear,
    SisStudentStatus? status,
    String? gender,
    String? dateOfBirth,
    String? guardianName,
    String? phone,
    String? email,
    String? enrolledAt,
    String? feeAccountId,
    String? publicStudentId,
  }) {
    return SisStudent(
      id: student.id,
      studentName: studentName ?? student.studentName,
      admissionNumber: admissionNumber ?? student.admissionNumber,
      publicStudentId: publicStudentId ?? student.publicStudentId,
      classLabel: classLabel ?? student.classLabel,
      section: section ?? student.section,
      academicYear: academicYear ?? student.academicYear,
      status: status ?? student.status,
      gender: gender ?? student.gender,
      dateOfBirth: dateOfBirth ?? student.dateOfBirth,
      guardianName: guardianName ?? student.guardianName,
      phone: phone ?? student.phone,
      email: email ?? student.email,
      enrolledAt: enrolledAt ?? student.enrolledAt,
      feeAccountId: feeAccountId ?? student.feeAccountId,
    );
  }

  PendingEnrollmentRecord copyEnrollment(
    PendingEnrollmentRecord enrollment, {
    EnrollmentConversionStatus? conversionStatus,
    String? generatedAdmissionNumber,
    String? previewStudentId,
    String? seekingClass,
    String? section,
  }) {
    return PendingEnrollmentRecord(
      id: enrollment.id,
      studentName: enrollment.studentName,
      applicationId: enrollment.applicationId,
      seekingClass: seekingClass ?? enrollment.seekingClass,
      section: section ?? enrollment.section,
      academicYear: enrollment.academicYear,
      guardianName: enrollment.guardianName,
      phone: enrollment.phone,
      submittedAt: enrollment.submittedAt,
      conversionStatus: conversionStatus ?? enrollment.conversionStatus,
      generatedAdmissionNumber:
          generatedAdmissionNumber ?? enrollment.generatedAdmissionNumber,
      previewStudentId: previewStudentId ?? enrollment.previewStudentId,
      gender: enrollment.gender,
      dateOfBirth: enrollment.dateOfBirth,
    );
  }
}
