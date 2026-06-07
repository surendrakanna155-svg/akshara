import 'package:akshara_erp/core/repositories/api/sis/dto/academic_assignment_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/admissions_conversion_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/create_student_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/update_student_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/update_student_status_request_dto.dart';
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
    test('create student request uses snake_case keys', () {
      const request = CreateStudentRequest(
        studentName: 'Ananya Reddy',
        admissionNumber: 'ADM-2026-0142',
        classLabel: '5',
        section: 'A',
        academicYear: '2026–27',
        status: SisStudentStatus.prospect,
      );
      final json = CreateStudentRequestDto.fromDomain(request).toJson();
      expect(json['student_name'], 'Ananya Reddy');
      expect(json['admission_number'], 'ADM-2026-0142');
      expect(json['status'], 'prospect');
    });

    test('update student request omits null fields', () {
      final json = UpdateStudentRequestDto.fromDomain(
        const UpdateStudentRequest(classLabel: '6', section: 'B'),
      ).toJson();
      expect(json['class_label'], '6');
      expect(json.containsKey('student_name'), isFalse);
    });

    test('update student status serializes status enum', () {
      final json = UpdateStudentStatusRequestDto.fromDomain(
        const UpdateStudentStatusRequest(status: SisStudentStatus.transferred),
      ).toJson();
      expect(json['status'], 'transferred');
    });

    test('academic assignment payload includes student id', () {
      final json = AcademicAssignmentRequestDto.fromDomain(
        const AcademicAssignmentRequest(
          studentId: 'SIS-STU-10421',
          classLabel: '10',
          section: 'A',
          academicYear: '2026–27',
        ),
      ).toJson();
      expect(json['student_id'], 'SIS-STU-10421');
      expect(json['class_label'], '10');
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
      expect(json['enrollment_id'], 'enr_1');
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
      expect(students.any((student) => student.id == created.id), isTrue);
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
