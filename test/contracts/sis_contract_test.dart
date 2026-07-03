import 'package:akshara_erp/core/repositories/api/sis/api_sis_repository.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/sis_dashboard_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/mapper/sis_mapper.dart';
import 'package:akshara_erp/core/repositories/api/sis/remote/sis_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/sis/remote/sis_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/features/sis/sis_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contract_test_helpers.dart';

void main() {
  group('SIS repository contract', () {
    late MockSisRepository mockRepo;
    late ApiSisRepository apiRepo;

    setUp(() {
      mockRepo = MockSisRepository();
      apiRepo = ApiSisRepository(remote: SisRemoteDataSource(Dio()));
    });

    test('mock and api implement SisRepository', () {
      expect(mockRepo, isA<SisRepository>());
      expect(apiRepo, isA<SisRepository>());
    });

    test('getDashboard signatures match', () {
      expect(
        mockRepo.getDashboard,
        isA<Future<dynamic> Function({required RepositoryQuery query})>(),
      );
      expect(
        apiRepo.getDashboard,
        isA<Future<dynamic> Function({required RepositoryQuery query})>(),
      );
    });

    test('DTO mapping produces compatible dashboard KPIs', () async {
      final mockData = await mockRepo.getDashboard(query: kContractQuery);
      final fixture = SisDashboardDto.fromJson({
        'aiInsight': mockData.aiInsight,
        'kpis': [
          for (final kpi in mockData.kpis)
            kpiJson(
              id: kpi.id,
              value: kpi.value,
              label: kpi.label,
              accentName: kpi.accentName,
              detail: kpi.detail,
            ),
        ],
      });

      final mapped = const SisMapper().toDashboard(fixture);

      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
      expect(
        mapped.kpis.map((k) => k.label).toList(),
        mockData.kpis.map((k) => k.label).toList(),
      );
    });
  });

  group('Identity Platform — public student ID mapping', () {
    const mapper = SisMapper();

    test('directory row maps publicStudentId; empty string → null', () {
      final withPsid = mapper.toStudentFromDirectory({
        'studentId': 'stu-1',
        'displayName': 'Public Student',
        'admissionNumber': 'ADM-001',
        'publicStudentId': 'DPSKKP-0007',
        'status': 'active',
      });
      expect(withPsid.publicStudentId, 'DPSKKP-0007');

      final codeless = mapper.toStudentFromDirectory({
        'studentId': 'stu-2',
        'displayName': 'No Code',
        'admissionNumber': 'ADM-002',
        'publicStudentId': '',
        'status': 'active',
      });
      expect(codeless.publicStudentId, isNull);
    });

    test('student detail maps publicStudentId from the profile block', () {
      final student = mapper.toStudentFromDetail({
        'student': {'id': 'stu-1', 'displayName': 'Public Student', 'status': 'active'},
        'profile': {
          'admissionNumber': 'ADM-001',
          'publicStudentId': 'DPSKKP-0009',
        },
        'currentEnrollment': {'className': '5', 'sectionName': 'A'},
        'guardians': const [],
      });
      expect(student.publicStudentId, 'DPSKKP-0009');
    });
  });

  group('SIS-1 — certificate paths + mapping', () {
    const mapper = SisMapper();

    test('certificate routes match the deployed backend', () {
      expect(
        SisApiPaths.studentCertificates('abc'),
        '/sis/students/abc/certificates',
      );
      expect(
        SisApiPaths.studentTransferCertificate('abc'),
        '/sis/students/abc/transfer-certificate',
      );
    });

    test('maps the certificate DATA envelope (issuance payload)', () {
      final data = mapper.toCertificateData({
        'issueId': 'cert-1',
        'certificateType': 'transfer',
        'serialNo': 'TC/DPSKKP/2026-27/0001',
        'reason': 'relocation',
        'issuedAt': '2026-07-03T00:00:00.000Z',
        'student': {
          'displayName': 'Arjun Patel',
          'publicStudentId': 'DPSKKP-0001',
          'admissionNumber': 'ADM-2026-0138',
          'className': '10',
          'sectionName': 'A',
          'academicYear': '2026-27',
          'dateOfBirth': '2011-06-14',
          'guardianName': 'Kiran Patel',
          'status': 'transferred',
        },
        'school': {'name': 'Akshara Public School', 'code': 'DPSKKP'},
      });
      expect(data.type, SisCertificateType.transfer);
      expect(data.serialNo, 'TC/DPSKKP/2026-27/0001');
      expect(data.publicStudentId, 'DPSKKP-0001');
      expect(data.studentName, 'Arjun Patel');
      expect(data.schoolCode, 'DPSKKP');
    });

    test('code-less school certificate maps public ID to null', () {
      final data = mapper.toCertificateData({
        'issueId': 'cert-2',
        'certificateType': 'bonafide',
        'serialNo': '',
        'student': {
          'displayName': 'No Code',
          'publicStudentId': '',
          'admissionNumber': 'ADM-002',
        },
        'school': {'name': 'X', 'code': ''},
      });
      expect(data.serialNo, isNull);
      expect(data.publicStudentId, isNull);
      expect(data.type, SisCertificateType.bonafide);
    });

    test('maps a certificate issuance-register row', () {
      final issue = mapper.toCertificateIssue({
        'id': 'cert-1',
        'type': 'study',
        'serialNo': '',
        'reason': 'bank',
        'issuedBy': 'user-1',
        'issuedAt': '2026-07-03T00:00:00.000Z',
      });
      expect(issue.type, SisCertificateType.study);
      expect(issue.serialNo, isNull);
      expect(issue.reason, 'bank');
      expect(issue.issuedBy, 'user-1');
    });
  });
}
