import 'package:akshara_erp/core/repositories/api/sis/api_sis_repository.dart';
import 'package:akshara_erp/core/repositories/api/sis/remote/sis_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/sis/remote/sis_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/sis/dashboard/sis_dashboard_provider.dart';
import 'package:akshara_erp/features/sis/sis_models.dart';
import 'package:akshara_erp/features/sis/sis_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/sis/sis_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = SisFixtureBuilder();

void main() {
  group('SIS API integration', () {
    late MockSisRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUp(() async {
      mockRepo = MockSisRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final students = await mockRepo.getStudents(query: kQuery);
      final profile = await mockRepo.getStudentProfile(
        query: kQuery,
        studentId: students.items.first.id,
      );
      final assignment = await mockRepo.getAcademicAssignment(query: kQuery);
      final conversion = await mockRepo.getAdmissionsConversion(query: kQuery);

      responseForPath = (path) {
        if (path == SisApiPaths.dashboard) {
          return _fixtures.dashboardEnvelope(dashboard);
        }
        if (path == SisApiPaths.students) {
          return _fixtures.listEnvelope([
            for (final student in students.items)
              _fixtures.studentItem(student),
          ]);
        }
        if (path.startsWith('${SisApiPaths.students}/')) {
          return _fixtures.profileEnvelope(profile);
        }
        if (path == SisApiPaths.academicAssignment) {
          return _fixtures.academicAssignmentEnvelope(assignment);
        }
        if (path == SisApiPaths.admissionsConversion) {
          return _fixtures.conversionEnvelope(conversion);
        }
        return {'data': {}};
      };
    });

    Dio createTestDio() {
      return createFakeDio((options) {
        if (options.method == 'POST' && options.path == SisApiPaths.students) {
          return _fixtures.profileEnvelope(
            const SisStudentProfile(
              student: SisStudent(
                id: 'SIS-STU-NEW',
                studentName: 'Created Via API',
                admissionNumber: 'ADM-2026-NEW',
                classLabel: '5',
                section: 'A',
                academicYear: '2026–27',
                status: SisStudentStatus.prospect,
                gender: 'Female',
                dateOfBirth: '01 Jan 2016',
                guardianName: 'Parent',
                phone: '+91 90000 00000',
                email: 'parent@email.com',
                enrolledAt: 'Today',
              ),
              parent: SisParentDetails(
                guardianName: 'Parent',
                relationship: 'Guardian',
                phone: '+91 90000 00000',
                email: 'parent@email.com',
                address: '',
              ),
              academicHistory: [],
              attendance: SisAttendanceSummary(
                presentPercent: '—',
                absentDays: 0,
                lateDays: 0,
                periodLabel: '',
              ),
              documents: [],
              timeline: [],
              feeAccount: null,
            ),
          );
        }
        if (options.method == 'POST' &&
            options.path == SisApiPaths.enrollments) {
          return _fixtures.envelope({
            'studentId': 'SIS-STU-10421',
            'studentName': 'Arjun Patel',
            'className': '11',
            'sectionName': 'C',
            'academicYear': '2026–27',
          });
        }
        if (options.method == 'POST' &&
            options.path == SisApiPaths.admissionsConversion) {
          return _fixtures.conversionPreviewEnvelope(
            const SisConversionPreview(
              studentId: 'SIS-STU-10499',
              admissionNumber: 'ADM-2026-0499',
              studentName: 'Vihaan Sharma',
              classLabel: '8',
              section: 'B',
              academicYear: '2026–27',
            ),
          );
        }
        if (options.method == 'POST' &&
            options.path ==
                SisApiPaths.studentDocumentsPresign('SIS-STU-10421')) {
          // PRA-P1-19 — presign returns a signed URL + the tenant-scoped path.
          return _fixtures.envelope({
            'signedUrl': 'https://storage.local/upload?token=abc',
            'token': 'abc',
            'storagePath': 'org/school/SIS-STU-10421/uuid_tc.pdf',
          });
        }
        if (options.method == 'GET' &&
            options.path ==
                SisApiPaths.studentDocumentDownload(
                    'SIS-STU-10421', 'SIS-DOC-1201')) {
          return _fixtures.envelope({
            'downloadUrl': 'https://storage.local/download?token=xyz',
          });
        }
        if (options.method == 'POST' &&
            options.path == SisApiPaths.studentDocuments('SIS-STU-10421')) {
          return _fixtures.envelope({
            'id': 'SIS-DOC-1201',
            'type': 'Transfer Certificate',
            'status': 'Pending',
            'uploadedAt': 'Today',
          });
        }
        return responseForPath(options.path);
      });
    }

    test('remote datasource returns dashboard payload', () async {
      final remote = SisRemoteDataSource(
        createFakeDio(
          (options) => responseForPath(options.path),
        ),
      );

      final dto = await remote.fetchDashboard(query: kQuery);
      expect(dto.raw['aiInsight'], isNotEmpty);
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiSisRepository(
        remote: SisRemoteDataSource(
          createFakeDio((options) => responseForPath(options.path)),
        ),
      );

      final mockData = await mockRepo.getDashboard(query: kQuery);
      final apiData = await repository.getDashboard(query: kQuery);

      expect(apiData.kpis.length, mockData.kpis.length);
      expect(apiData.aiInsight, mockData.aiInsight);
    });

    test('provider chain loads dashboard in api mode', () async {
      final dio = createFakeDio((options) => responseForPath(options.path));
      final container = createProviderTestContainer(
        apiSisDio: dio,
        sisApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data = await container.read(sisDashboardFutureProvider.future);
      expect(data.kpis, isNotEmpty);
    });

    test('api repository createStudent maps POST response', () async {
      final repository = ApiSisRepository(
        remote: SisRemoteDataSource(createTestDio()),
      );

      final student = await repository.createStudent(
        query: kQuery,
        request: const CreateStudentRequest(
          studentName: 'Created Via API',
          admissionNumber: 'ADM-2026-NEW',
          classLabel: '5',
          section: 'A',
          academicYear: '2026–27',
        ),
      );

      expect(student.id, 'SIS-STU-NEW');
      expect(student.studentName, 'Created Via API');
    });

    test('api repository assignAcademicAssignment maps POST response',
        () async {
      final repository = ApiSisRepository(
        remote: SisRemoteDataSource(createTestDio()),
      );

      final student = await repository.assignAcademicAssignment(
        query: kQuery,
        request: const AcademicAssignmentRequest(
          studentId: 'SIS-STU-10421',
          classLabel: '11',
          section: 'C',
          academicYear: '2026–27',
        ),
      );

      expect(student.classLabel, '11');
      expect(student.section, 'C');
    });

    test('api repository convertAdmissionsEnrollment maps POST response',
        () async {
      final repository = ApiSisRepository(
        remote: SisRemoteDataSource(createTestDio()),
      );

      final preview = await repository.convertAdmissionsEnrollment(
        query: kQuery,
        request: const AdmissionsConversionRequest(
          enrollmentId: 'enr_2',
          classLabel: '8',
          section: 'B',
          academicYear: '2026–27',
        ),
      );

      expect(preview.studentId, 'SIS-STU-10499');
      expect(preview.admissionNumber, 'ADM-2026-0499');
    });

    test('api repository uploadStudentDocument maps POST response', () async {
      final repository = ApiSisRepository(
        remote: SisRemoteDataSource(createTestDio()),
      );

      final document = await repository.uploadStudentDocument(
        query: kQuery,
        studentId: 'SIS-STU-10421',
        request: const UploadStudentDocumentRequest(
          type: 'Transfer Certificate',
          fileName: 'tc.pdf',
        ),
      );

      expect(document.id, 'SIS-DOC-1201');
      expect(document.type, 'Transfer Certificate');
      expect(document.status, 'Pending');
    });

    test('PRA-P1-19 presignStudentDocumentUpload maps signed URL + storage path',
        () async {
      final remote = SisRemoteDataSource(createTestDio());

      final presign = await remote.presignStudentDocumentUpload(
        query: kQuery,
        studentId: 'SIS-STU-10421',
        fileName: 'tc.pdf',
      );

      expect(presign.signedUrl, 'https://storage.local/upload?token=abc');
      expect(presign.storagePath, 'org/school/SIS-STU-10421/uuid_tc.pdf');
    });

    test('PRA-P1-19 fetchStudentDocumentDownloadUrl maps download URL',
        () async {
      final remote = SisRemoteDataSource(createTestDio());

      final url = await remote.fetchStudentDocumentDownloadUrl(
        query: kQuery,
        studentId: 'SIS-STU-10421',
        documentId: 'SIS-DOC-1201',
      );

      expect(url, 'https://storage.local/download?token=xyz');
    });
  });
}
