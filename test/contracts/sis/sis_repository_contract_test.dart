import 'package:akshara_erp/core/repositories/api/sis/api_sis_repository.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/sis_enum_codec.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/sis_academic_assignment_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/sis_conversion_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/sis_dashboard_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/sis_student_profile_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/sis_students_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/mapper/sis_mapper.dart';
import 'package:akshara_erp/core/repositories/api/sis/remote/sis_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/sis_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sis_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = SisFixtureBuilder();
const _mapper = SisMapper();

void main() {
  group('SIS repository contract', () {
    late MockSisRepository mockRepo;
    late ApiSisRepository apiRepo;

    setUp(() {
      mockRepo = MockSisRepository();
      apiRepo = ApiSisRepository(
        remote: SisRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement SisRepository', () {
      expect(mockRepo, isA<SisRepository>());
      expect(apiRepo, isA<SisRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        SisDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );

      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
      expect(mapped.classDistribution.length, mockData.classDistribution.length);
      expect(mapped.recentEnrollments.length, mockData.recentEnrollments.length);
    });

    test('getStudents DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getStudents(query: kQuery);
      final mapped = _mapper.toStudents(
        SisStudentsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final student in mockData.items) _fixtures.studentItem(student),
          ]),
        ),
      );

      expect(mapped.length, mockData.items.length);
      expect(mapped.first.admissionNumber, mockData.items.first.admissionNumber);
    });

    test('getStudentProfile DTO mapping matches mock output', () async {
      final mockProfile = await mockRepo.getStudentProfile(
        query: kQuery,
        studentId: 'SIS-STU-10421',
      );
      final mapped = _mapper.toStudentProfile(
        SisStudentProfileDto.fromJson(
          _fixtures.profileEnvelope(mockProfile),
        ),
      );

      expect(mapped.student.id, mockProfile.student.id);
      expect(mapped.parent.guardianName, mockProfile.parent.guardianName);
      expect(mapped.documents.length, mockProfile.documents.length);
    });

    test('getStudentProfile maps nested server envelope with documents', () async {
      final mockProfile = await mockRepo.getStudentProfile(
        query: kQuery,
        studentId: 'SIS-STU-10421',
      );
      final mapped = _mapper.toStudentProfile(
        SisStudentProfileDto.fromJson(
          _fixtures.envelope({
            'student': {
              'id': mockProfile.student.id,
              'studentCode': mockProfile.student.id,
              'displayName': mockProfile.student.studentName,
              'status': SisEnumCodec.studentStatusToApi(mockProfile.student.status),
            },
            'profile': {
              'admissionNumber': mockProfile.student.admissionNumber,
            },
            'currentEnrollment': {
              'className': mockProfile.student.classLabel,
              'sectionName': mockProfile.student.section,
              'isCurrent': true,
            },
            'guardians': [
              {
                'displayName': mockProfile.parent.guardianName,
                'relationship': mockProfile.parent.relationship,
                'phone': mockProfile.parent.phone,
                'email': mockProfile.parent.email,
              },
            ],
            'documents': [
              for (final document in mockProfile.documents)
                {
                  'type': document.type,
                  'status': document.status,
                  'uploadedAt': document.uploadedAt,
                },
            ],
          }),
        ),
      );

      expect(mapped.documents.length, mockProfile.documents.length);
      expect(mapped.documents.first.type, mockProfile.documents.first.type);
    });

    test('getAcademicAssignment DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAcademicAssignment(query: kQuery);
      final mapped = _mapper.toAcademicAssignment(
        SisAcademicAssignmentDto.fromJson(
          _fixtures.academicAssignmentEnvelope(mockData),
        ),
      );

      expect(mapped.classOptions, mockData.classOptions);
      expect(mapped.sectionOptions, mockData.sectionOptions);
      expect(mapped.academicYearOptions, mockData.academicYearOptions);
    });

    test('getAdmissionsConversion DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAdmissionsConversion(query: kQuery);
      final mapped = _mapper.toAdmissionsConversion(
        SisConversionResponseDto.fromJson(
          _fixtures.conversionEnvelope(mockData),
        ),
      );

      expect(mapped.queue.length, mockData.queue.length);
      expect(
        mapped.queue.first.enrollment.studentName,
        mockData.queue.first.enrollment.studentName,
      );
    });

    test('mock repository exposes all five methods', () async {
      expect(await mockRepo.getDashboard(query: kQuery), isNotNull);
      expect((await mockRepo.getStudents(query: kQuery)).items, isNotEmpty);
      expect(
        await mockRepo.getStudentProfile(
          query: kQuery,
          studentId: 'SIS-STU-10421',
        ),
        isNotNull,
      );
      expect(await mockRepo.getAcademicAssignment(query: kQuery), isNotNull);
      expect(await mockRepo.getAdmissionsConversion(query: kQuery), isNotNull);
    });
  });
}
