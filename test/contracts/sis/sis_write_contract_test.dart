import 'package:akshara_erp/core/repositories/api/sis/dto/academic_assignment_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/admissions_conversion_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/create_student_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/upload_student_document_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/update_student_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/update_student_status_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/verify_student_document_request_dto.dart';
import 'package:akshara_erp/core/repositories/interfaces/sis_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/sis/sis_models.dart';
import 'package:akshara_erp/features/sis/sis_requests.dart';
import 'package:flutter_test/flutter_test.dart';

const kQuery = RepositoryQuery.demo;

void main() {
  group('SIS write DTO serialization', () {
    test('create student request uses backend field aliases', () {
      const request = CreateStudentRequest(
        studentName: 'Ananya Reddy',
        admissionNumber: 'ADM-2026-0142',
        classLabel: '5',
        section: 'A',
        academicYear: '2026–27',
        status: SisStudentStatus.prospect,
      );
      final json = CreateStudentRequestDto.fromDomain(request).toJson();
      expect(json['displayName'], 'Ananya Reddy');
      expect(json['admissionNumber'], 'ADM-2026-0142');
      expect(json['status'], 'active');
    });

    test('update student request omits null fields', () {
      final json = UpdateStudentRequestDto.fromDomain(
        const UpdateStudentRequest(classLabel: '6', section: 'B'),
      ).toJson();
      expect(json.containsKey('displayName'), isFalse);
      expect(json.containsKey('student_name'), isFalse);
    });

    test('update student status serializes status enum', () {
      final json = UpdateStudentStatusRequestDto.fromDomain(
        const UpdateStudentStatusRequest(status: SisStudentStatus.transferred),
      ).toJson();
      expect(json['status'], 'transferred');
    });

    test('upload student document request serializes payload', () {
      final json = UploadStudentDocumentRequestDto.fromDomain(
        const UploadStudentDocumentRequest(
          type: 'Transfer Certificate',
          fileName: 'tc.pdf',
        ),
      ).toJson();
      expect(json['type'], 'Transfer Certificate');
      expect(json['fileName'], 'tc.pdf');
      expect(json['status'], 'Pending');
    });

    test('academic assignment payload targets enrollment create body', () {
      final json = AcademicAssignmentRequestDto.fromDomain(
        const AcademicAssignmentRequest(
          studentId: 'SIS-STU-10421',
          classLabel: '10',
          section: 'A',
          academicYear: '2026–27',
        ),
      ).toJson();
      expect(json['studentId'], 'SIS-STU-10421');
      expect(json['className'], '10');
    });

    test('verify document request serializes status and optional note', () {
      final withNote = VerifyStudentDocumentRequestDto.fromDomain(
        const VerifyStudentDocumentRequest(
          decision: SisDocumentDecision.verified,
          note: 'Original sighted',
        ),
      ).toJson();
      expect(withNote['status'], 'verified');
      expect(withNote['note'], 'Original sighted');

      final withoutNote = VerifyStudentDocumentRequestDto.fromDomain(
        const VerifyStudentDocumentRequest(
          decision: SisDocumentDecision.rejected,
        ),
      ).toJson();
      expect(withoutNote['status'], 'rejected');
      expect(withoutNote.containsKey('note'), isFalse);
    });

    test('admissions conversion payload includes enrollment id', () {
      final json = AdmissionsConversionRequestDto.fromDomain(
        const AdmissionsConversionRequest(
          enrollmentId: 'enr_1',
          classLabel: '5',
          section: 'A',
          academicYear: '2026–27',
        ),
      ).toJson();
      expect(json['enrollmentId'], 'enr_1');
      expect(json['section'], 'A');
    });
  });

  group('Mock SIS write repository', () {
    late MockSisRepository repo;

    setUp(() {
      repo = MockSisRepository();
    });

    test('implements all write methods on SisRepository', () {
      expect(repo, isA<SisRepository>());
    });

    test('createStudent returns persisted student in subsequent getStudents',
        () async {
      final created = await repo.createStudent(
        query: kQuery,
        request: const CreateStudentRequest(
          studentName: 'Test Student',
          admissionNumber: 'ADM-2026-9999',
          classLabel: '4',
          section: 'A',
          academicYear: '2026–27',
        ),
      );
      final students = await repo.getStudents(query: kQuery);
      expect(students.items.any((student) => student.id == created.id), isTrue);
    });

    test('assignAcademicAssignment updates class and section', () async {
      const studentId = 'SIS-STU-10421';
      final updated = await repo.assignAcademicAssignment(
        query: kQuery,
        request: const AcademicAssignmentRequest(
          studentId: studentId,
          classLabel: '11',
          section: 'C',
          academicYear: '2026–27',
        ),
      );
      expect(updated.classLabel, '11');
      expect(updated.section, 'C');
    });

    test('updateStudentStatus changes lifecycle status', () async {
      const studentId = 'SIS-STU-10405';
      final updated = await repo.updateStudentStatus(
        query: kQuery,
        studentId: studentId,
        request: const UpdateStudentStatusRequest(
          status: SisStudentStatus.active,
        ),
      );
      expect(updated.status, SisStudentStatus.active);
    });

    test('updateStudent persists edited fields', () async {
      const studentId = 'SIS-STU-10421';
      final updated = await repo.updateStudent(
        query: kQuery,
        studentId: studentId,
        request: const UpdateStudentRequest(
          studentName: 'Arjun Patel Updated',
          guardianName: 'Kiran Patel Updated',
          phone: '+91 90000 12345',
        ),
      );
      expect(updated.studentName, 'Arjun Patel Updated');
      expect(updated.guardianName, 'Kiran Patel Updated');
      expect(updated.phone, '+91 90000 12345');
    });

    test('uploadStudentDocument persists for student profile', () async {
      const studentId = 'SIS-STU-10421';
      final uploaded = await repo.uploadStudentDocument(
        query: kQuery,
        studentId: studentId,
        request: const UploadStudentDocumentRequest(
          type: 'Transfer Certificate',
          fileName: 'tc.pdf',
        ),
      );
      expect(uploaded.id, isNotNull);
      expect(uploaded.type, 'Transfer Certificate');

      final profile = await repo.getStudentProfile(
        query: kQuery,
        studentId: studentId,
      );
      expect(profile.documents.first.type, 'Transfer Certificate');
    });

    test('verifyStudentDocument flips the pending document to verified',
        () async {
      const studentId = 'SIS-STU-10421';
      const documentId = 'SIS-DOC-903';
      final updated = await repo.verifyStudentDocument(
        query: kQuery,
        studentId: studentId,
        documentId: documentId,
        request: const VerifyStudentDocumentRequest(
          decision: SisDocumentDecision.verified,
          note: 'Checked against original',
        ),
      );
      expect(updated.id, documentId);
      expect(updated.status, 'verified');
      expect(updated.verifiedBy, isNotNull);
      expect(updated.verifiedAt, isNotNull);

      final profile = await repo.getStudentProfile(
        query: kQuery,
        studentId: studentId,
      );
      final persisted =
          profile.documents.firstWhere((doc) => doc.id == documentId);
      expect(persisted.status, 'verified');
    });

    test('verifyStudentDocument rejects and unknown document throws',
        () async {
      const studentId = 'SIS-STU-10418';
      const documentId = 'SIS-DOC-903';
      final updated = await repo.verifyStudentDocument(
        query: kQuery,
        studentId: studentId,
        documentId: documentId,
        request: const VerifyStudentDocumentRequest(
          decision: SisDocumentDecision.rejected,
        ),
      );
      expect(updated.status, 'rejected');

      expect(
        () => repo.verifyStudentDocument(
          query: kQuery,
          studentId: studentId,
          documentId: 'SIS-DOC-MISSING',
          request: const VerifyStudentDocumentRequest(
            decision: SisDocumentDecision.verified,
          ),
        ),
        throwsStateError,
      );
    });

    test('convertAdmissionsEnrollment creates student and marks converted',
        () async {
      final preview = await repo.convertAdmissionsEnrollment(
        query: kQuery,
        request: const AdmissionsConversionRequest(
          enrollmentId: 'enr_1',
          classLabel: '5',
          section: 'A',
          academicYear: '2026–27',
        ),
      );
      expect(preview.studentId, isNotEmpty);
      expect(preview.admissionNumber, startsWith('ADM-'));

      final conversion = await repo.getAdmissionsConversion(query: kQuery);
      final item = conversion.queue.firstWhere(
        (entry) => entry.enrollment.id == 'enr_1',
      );
      expect(item.effectiveStatus, EnrollmentConversionStatus.converted);
    });
  });
}
