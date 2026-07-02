import 'dart:io';

import 'package:akshara_erp/core/repositories/api/sis/dto/sis_dashboard_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/academic_assignment_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/admissions_conversion_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/create_student_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/enrollment_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/upload_student_document_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/sis_enum_codec.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/update_student_status_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/mapper/sis_mapper.dart';
import 'package:akshara_erp/core/repositories/api/sis/remote/sis_api_paths.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/features/sis/sis_models.dart';
import 'package:akshara_erp/features/sis/sis_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SIS API paths', () {
    test('enrollment routes match deployed backend', () {
      expect(SisApiPaths.enrollments, '/sis/enrollments');
      expect(SisApiPaths.enrollment('abc'), '/sis/enrollments/abc');
      expect(
          SisApiPaths.studentDocuments('abc'), '/sis/students/abc/documents');
      expect(SisApiPaths.admissionsConversion, '/sis/admissions-conversion');
    });

    test('transfers and document-verify routes match deployed backend', () {
      expect(SisApiPaths.transfers, '/sis/transfers');
      expect(
        SisApiPaths.studentDocumentVerify('abc', 'doc1'),
        '/sis/students/abc/documents/doc1/verify',
      );
    });
  });

  group('SIS DTO alignment', () {
    test('create student sends backend camelCase aliases', () {
      const request = CreateStudentRequest(
        studentName: 'Ananya Reddy',
        admissionNumber: 'ADM-2026-0142',
        classLabel: '5',
        section: 'A',
        academicYear: '2026-27',
      );
      final json = CreateStudentRequestDto.fromDomain(request).toJson();
      expect(json['displayName'], 'Ananya Reddy');
      expect(json['admissionNumber'], 'ADM-2026-0142');
    });

    test('enrollment create maps academic assignment to /sis/enrollments body',
        () {
      final json = EnrollmentCreateRequestDto.fromAcademicAssignment(
        const AcademicAssignmentRequest(
          studentId: 'student-1',
          classLabel: '10',
          section: 'A',
          academicYear: '2026-27',
        ),
      ).toJson();
      expect(json['studentId'], 'student-1');
      expect(json['className'], '10');
      expect(json['isCurrent'], isTrue);
    });

    test('conversion request includes enrollment and class aliases', () {
      final json = AdmissionsConversionRequestDto.fromDomain(
        const AdmissionsConversionRequest(
          enrollmentId: 'enr-1',
          classLabel: '5',
          section: 'A',
          academicYear: '2026-27',
        ),
      ).toJson();
      expect(json['enrollmentId'], 'enr-1');
      expect(json['className'], '5');
    });

    test('status codec maps graduated and inactive for API', () {
      expect(
        SisEnumCodec.studentStatusToApi(SisStudentStatus.alumni),
        'graduated',
      );
      expect(
        SisEnumCodec.studentStatusToApi(SisStudentStatus.exited),
        'inactive',
      );
      expect(
        SisEnumCodec.parseStudentStatus('graduated'),
        SisStudentStatus.alumni,
      );
      expect(
        SisEnumCodec.parseStudentStatus('inactive'),
        SisStudentStatus.exited,
      );
    });

    test('academic assignment DTO delegates to enrollment payload', () {
      final json = AcademicAssignmentRequestDto.fromDomain(
        const AcademicAssignmentRequest(
          studentId: 'student-1',
          classLabel: '8',
          section: 'B',
          academicYear: '2026-27',
        ),
      ).toJson();
      expect(json['className'], '8');
      expect(json.containsKey('studentId'), isTrue);
    });

    test('status update serializes graduated as API value', () {
      final json = UpdateStudentStatusRequestDto.fromDomain(
        const UpdateStudentStatusRequest(status: SisStudentStatus.alumni),
      ).toJson();
      expect(json['status'], 'graduated');
    });

    test('document upload request serializes doc metadata', () {
      final json = UploadStudentDocumentRequestDto.fromDomain(
        const UploadStudentDocumentRequest(
          type: 'Transfer Certificate',
          fileName: 'tc.pdf',
        ),
      ).toJson();
      expect(json['type'], 'Transfer Certificate');
      expect(json['fileName'], 'tc.pdf');
    });
  });

  group('SIS mapper alignment', () {
    const mapper = SisMapper();

    test('maps deployed directory list item', () {
      final student = mapper.toStudentFromDirectory({
        'studentId': 'stu-1',
        'displayName': 'Staging Student',
        'studentCode': 'STU-2026-00001',
        'admissionNumber': 'ADM-001',
        'className': '5',
        'sectionName': 'A',
        'academicYear': '2026-27',
        'status': 'active',
      });
      expect(student.id, 'stu-1');
      expect(student.studentName, 'Staging Student');
      expect(student.classLabel, '5');
    });

    test('directory item maps primary guardian contact (SIS-2)', () {
      final student = mapper.toStudentFromDirectory({
        'studentId': 'stu-1',
        'displayName': 'Staging Student',
        'admissionNumber': 'ADM-001',
        'status': 'active',
        'guardianName': 'Parent One',
        'guardianPhone': '+919876543210',
        'guardianCount': 1,
      });
      expect(student.guardianName, 'Parent One');
      expect(student.phone, '+919876543210');

      // Backend sends empty strings when no primary guardian is on record.
      final orphan = mapper.toStudentFromDirectory({
        'studentId': 'stu-2',
        'displayName': 'No Guardian',
        'status': 'active',
        'guardianName': '',
        'guardianPhone': '',
      });
      expect(orphan.guardianName, isEmpty);
      expect(orphan.phone, isEmpty);
    });

    test('maps deployed transfer list item (SIS-5)', () {
      final record = mapper.toTransferRecord({
        'studentId': 'stu-9',
        'studentCode': 'STU-2024-00009',
        'displayName': 'Exited Student',
        'status': 'graduated',
        'admissionNumber': 'ADM-009',
        'academicYear': '2024-25',
        'className': '12',
        'sectionName': 'A',
        'rollNumber': '9',
        'transitionedAt': '2026-03-31T10:00:00.000Z',
        'createdAt': '2020-06-01T00:00:00.000Z',
      });
      expect(record.studentId, 'stu-9');
      expect(record.studentName, 'Exited Student');
      expect(record.admissionNumber, 'ADM-009');
      expect(record.classLabel, '12');
      expect(record.section, 'A');
      expect(record.academicYear, '2024-25');
      expect(record.status, SisStudentStatus.alumni);
      expect(record.exitedAt, '2026-03-31T10:00:00.000Z');

      final transferred = mapper.toTransferRecord({
        'studentId': 'stu-10',
        'displayName': 'Moved Student',
        'status': 'transferred',
        'transitionedAt': '2026-01-15T08:00:00.000Z',
      });
      expect(transferred.status, SisStudentStatus.transferred);
    });

    test('maps deployed verified document envelope (SIS-3)', () {
      final document = mapper.toDocumentSummary({
        'id': 'doc-1',
        'type': 'Transfer Certificate',
        'documentType': 'Transfer Certificate',
        'status': 'verified',
        'fileUri': null,
        'uploadedAt': '2026-06-01T00:00:00.000Z',
        'verifiedAt': '2026-06-02T00:00:00.000Z',
        'verifiedBy': 'user-1',
      });
      expect(document.id, 'doc-1');
      expect(document.type, 'Transfer Certificate');
      expect(document.status, 'verified');
      expect(document.verifiedBy, 'user-1');
      expect(document.verifiedAt, '2026-06-02T00:00:00.000Z');

      final pending = mapper.toDocumentSummary({
        'id': 'doc-2',
        'documentType': 'Aadhaar',
        'status': 'pending',
        'uploadedAt': '2026-06-01T00:00:00.000Z',
        'verifiedAt': null,
        'verifiedBy': null,
      });
      expect(pending.type, 'Aadhaar');
      expect(pending.verifiedBy, isNull);
    });

    test('maps deployed student detail envelope', () {
      final student = mapper.toStudentFromDetail({
        'student': {
          'id': 'stu-1',
          'displayName': 'Staging Student',
          'status': 'graduated',
        },
        'profile': {
          'admissionNumber': 'ADM-001',
          'gender': 'male',
        },
        'currentEnrollment': {
          'className': '5',
          'sectionName': 'A',
          'academicYear': '2026-27',
        },
        'guardians': [
          {
            'displayName': 'Parent',
            'phone': '+919876543210',
            'email': 'parent@test.com',
            'relationship': 'mother',
          },
        ],
      });
      expect(student.id, 'stu-1');
      expect(student.status, SisStudentStatus.alumni);
      expect(student.guardianName, 'Parent');
    });

    test('maps deployed dashboard aggregate envelope', () {
      const mapper = SisMapper();
      final dashboard = mapper.toDashboard(
        SisDashboardDto.fromJson({
          'data': {
            'totalStudents': 3,
            'activeStudents': 2,
            'inactiveStudents': 1,
            'graduatedStudents': 0,
            'transferredStudents': 0,
            'currentEnrollments': 2,
            'recentAdmissions': 1,
            'recentConversions': 1,
            'pendingConversions': 1,
            'distinctClasses': 2,
            'distinctSections': 2,
            'kpis': [
              {
                'id': 'total_students',
                'value': '3',
                'label': 'Total Students',
                'accentName': 'primary',
              },
            ],
            'classDistribution': [
              {'label': '5', 'count': 2, 'percent': 67},
            ],
            'genderDistribution': [
              {'label': 'Male', 'count': 1, 'percent': 50},
            ],
            'recentEnrollments': [
              {
                'id': 'enr-1',
                'studentName': 'Staging Student',
                'admissionNumber': 'ADM-001',
                'classLabel': '5',
                'section': 'A',
                'enrolledAt': '2026-06-10',
                'status': 'active',
              },
            ],
            'aiInsight': 'Dashboard ready.',
          },
        }),
      );
      expect(dashboard.kpis, isNotEmpty);
      expect(dashboard.classDistribution.first.label, '5');
      expect(dashboard.recentEnrollments.first.studentName, 'Staging Student');
      expect(dashboard.aiInsight, 'Dashboard ready.');
    });
  });

  group('Hybrid repository routing', () {
    test('HybridSisRepository routes dashboard to API layer', () {
      final content = File(
        'lib/core/repositories/api/sis/hybrid_sis_repository.dart',
      ).readAsStringSync();
      expect(content, contains('_api.getDashboard'));
      expect(content, contains('_api.verifyStudentDocument'));
      expect(content, contains('_api.listStudentTransfers'));
    });

    test('sisApiEnabledProvider is false without dart defines', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(sisApiEnabledProvider), isFalse);
    });

    test('sisRepositoryProvider returns mock by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(sisRepositoryProvider).runtimeType.toString(),
        contains('MockSisRepository'),
      );
    });
  });
}
