import 'package:akshara_erp/core/repositories/mock/mock_alumni_write_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_write_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/alumni/alumni_models.dart';
import 'package:akshara_erp/features/sis/sis_models.dart';
import 'package:akshara_erp/features/sis/sis_requests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    MockAlumniWriteStore.instance.reset();
    MockSisWriteStore.instance.students = null;
    MockSisWriteStore.instance.conversionQueue = null;
  });

  group('MockAlumniWriteStore — graduation automation', () {
    test('updateStudentStatus(alumni) creates alumni record', () async {
      final sisRepo = MockSisRepository();
      const query = RepositoryQuery.demo;
      await sisRepo.getStudents(query: query); // seed store

      final students = MockSisWriteStore.instance.students!;
      expect(students, isNotEmpty);
      final target = students.first;

      await sisRepo.updateStudentStatus(
        query: query,
        studentId: target.id,
        request: const UpdateStudentStatusRequest(status: SisStudentStatus.alumni),
      );

      expect(
        MockAlumniWriteStore.instance.hasGraduateForSisStudent(target.id),
        isTrue,
      );
    });

    test('onboardFromSisStudent is idempotent (no duplicate records)', () {
      final store = MockAlumniWriteStore.instance;
      const student = SisStudent(
        id: 'SIS-TEST-999',
        studentName: 'Idempotent Test',
        admissionNumber: 'ADM-999',
        classLabel: '12',
        section: 'A',
        academicYear: '2026–27',
        status: SisStudentStatus.alumni,
        gender: 'Male',
        dateOfBirth: '01 Jan 2007',
        guardianName: 'Test Guardian',
        phone: '+91 99900 00000',
        email: 'idempotent@test.com',
        enrolledAt: 'Jun 2026',
      );

      store.onboardFromSisStudent(student);
      store.onboardFromSisStudent(student);

      final matches =
          store.graduates.where((r) => r.sisStudentId == 'SIS-TEST-999');
      expect(matches, hasLength(1));
    });

    test('new graduate has pending engagement status', () {
      const student = SisStudent(
        id: 'SIS-TEST-998',
        studentName: 'New Graduate',
        admissionNumber: 'ADM-998',
        classLabel: '12',
        section: 'B',
        academicYear: '2026–27',
        status: SisStudentStatus.alumni,
        gender: 'Female',
        dateOfBirth: '15 Mar 2007',
        guardianName: 'Parent',
        phone: '',
        email: '',
        enrolledAt: 'Jan 2026',
      );
      final record = MockAlumniWriteStore.instance.onboardFromSisStudent(student);

      expect(record.engagementStatus, AlumniEngagementStatus.pending);
      expect(record.sisStudentId, 'SIS-TEST-998');
    });
  });
}
