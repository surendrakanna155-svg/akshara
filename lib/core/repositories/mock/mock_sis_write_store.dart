import '../../../features/admissions/admissions_models.dart';
import '../../../features/sis/sis_models.dart';

/// Mutable in-memory store backing mock SIS write operations.
class MockSisWriteStore {
  MockSisWriteStore._();

  static final MockSisWriteStore instance = MockSisWriteStore._();

  List<SisStudent>? students;
  List<SisEnrollmentQueueItem>? conversionQueue;
  Map<String, List<SisDocumentSummary>>? studentDocuments;

  int _studentSeq = 430;
  int _documentSeq = 900;

  String nextStudentId() => 'SIS-STU-10${++_studentSeq}';
  String nextDocumentId() => 'SIS-DOC-${++_documentSeq}';

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
  }) {
    return SisStudent(
      id: student.id,
      studentName: studentName ?? student.studentName,
      admissionNumber: admissionNumber ?? student.admissionNumber,
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
