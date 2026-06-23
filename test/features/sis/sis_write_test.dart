import 'package:akshara_erp/core/repositories/api/sis/remote/sis_api_paths.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/sis/sis_mutations_provider.dart';
import 'package:akshara_erp/features/sis/sis_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  group('SIS RBAC mutations', () {
    test('createStudent fails when manageSis permission missing', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.management),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createStudentProvider.notifier).execute(
            const CreateStudentRequest(
              studentName: 'Test',
              admissionNumber: 'ADM-2026-0001',
              classLabel: '5',
              section: 'A',
              academicYear: '2026–27',
            ),
          );

      expect(container.read(createStudentProvider).hasError, isTrue);
      expect(container.read(createStudentProvider).valueOrNull, isNull);
    });

    test('uploadStudentDocument fails when manageSis permission missing',
        () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.management),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(uploadStudentDocumentProvider.notifier).execute(
            studentId: 'SIS-STU-10421',
            request: const UploadStudentDocumentRequest(
              type: 'Transfer Certificate',
              fileName: 'tc.pdf',
            ),
          );

      expect(container.read(uploadStudentDocumentProvider).hasError, isTrue);
      expect(container.read(uploadStudentDocumentProvider).valueOrNull, isNull);
    });
  });

  group('SIS API write paths', () {
    test('maps resource ids to REST endpoints', () {
      expect(SisApiPaths.studentProfile('SIS-1'), '/sis/students/SIS-1');
      expect(SisApiPaths.studentStatus('SIS-1'), '/sis/students/SIS-1/status');
      expect(SisApiPaths.enrollments, '/sis/enrollments');
      expect(SisApiPaths.enrollment('SIS-1'), '/sis/enrollments/SIS-1');
      expect(
        SisApiPaths.studentDocuments('SIS-1'),
        '/sis/students/SIS-1/documents',
      );
      expect(SisApiPaths.admissionsConversion, '/sis/admissions-conversion');
    });
  });

  group('SIS mutation providers', () {
    test('assignAcademicAssignment updates student via repository', () async {
      final container = createProviderTestContainer(
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.schoolAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final updated = await container
          .read(assignAcademicAssignmentProvider.notifier)
          .execute(
            const AcademicAssignmentRequest(
              studentId: 'SIS-STU-10421',
              classLabel: '12',
              section: 'B',
              academicYear: '2026–27',
            ),
          );

      expect(updated, isNotNull);
      expect(updated!.classLabel, '12');
      expect(updated.section, 'B');
    });

    test('bulkAcademicAssignment assigns every listed student', () async {
      final container = createProviderTestContainer(
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.schoolAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final assigned = await container
          .read(bulkAcademicAssignmentProvider.notifier)
          .execute(
            const BulkAcademicAssignmentRequest(
              studentIds: ['SIS-STU-10421', 'SIS-STU-10418', 'SIS-STU-10415'],
              classLabel: '9',
              section: 'C',
              academicYear: '2026–27',
            ),
          );

      expect(assigned, 3);

      final students = await container.read(sisRepositoryProvider).getStudents(
            query: container.read(repositoryQueryProvider),
          );
      for (final id in ['SIS-STU-10421', 'SIS-STU-10418', 'SIS-STU-10415']) {
        final student = students.items.firstWhere((s) => s.id == id);
        expect(student.classLabel, '9');
        expect(student.section, 'C');
      }
    });

    test('bulkAcademicAssignment rejects an empty selection', () async {
      final container = createProviderTestContainer(
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.schoolAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(bulkAcademicAssignmentProvider.notifier).execute(
            const BulkAcademicAssignmentRequest(
              studentIds: [],
              classLabel: '9',
              section: 'C',
              academicYear: '2026–27',
            ),
          );

      expect(container.read(bulkAcademicAssignmentProvider).hasError, isTrue);
    });

    test('bulkAcademicAssignment fails without manageSis', () async {
      final container = createProviderTestContainer(
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.management),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(bulkAcademicAssignmentProvider.notifier).execute(
            const BulkAcademicAssignmentRequest(
              studentIds: ['SIS-STU-10421'],
              classLabel: '9',
              section: 'C',
              academicYear: '2026–27',
            ),
          );

      expect(container.read(bulkAcademicAssignmentProvider).hasError, isTrue);
    });

    test('convertAdmissionsEnrollment returns preview', () async {
      final container = createProviderTestContainer(
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.schoolAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final preview = await container
          .read(convertAdmissionsEnrollmentProvider.notifier)
          .execute(
            const AdmissionsConversionRequest(
              enrollmentId: 'enr_2',
              classLabel: '8',
              section: 'B',
              academicYear: '2026–27',
            ),
          );

      expect(preview, isNotNull);
      expect(preview!.studentName, 'Vihaan Sharma');
      expect(preview.classLabel, '8');
    });
  });
}
