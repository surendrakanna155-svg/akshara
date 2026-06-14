import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/repositories/mock/mock_education_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/education/education_models.dart';
import 'package:akshara_erp/features/education/education_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  group('Education RBAC mutations', () {
    test('publishRemark fails without manageEducation', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.management),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container
            .read(educationMutationsProvider.notifier)
            .publishRemark('remark_1'),
        throwsA(isA<ApiFailureException>()),
      );
    });
  });

  group('Education mock remark publish', () {
    test('publishReportRemark updates status to published', () async {
      final repo = MockEducationRepository();
      const query = RepositoryQuery.demo;

      final remark = await repo.generateReportRemark(
        query: query,
        request: const GenerateReportRemarkRequest(
          studentId: 'student_1',
          academicYearLabel: '2025-26',
          remarkType: EduRemarkType.classTeacher,
          language: EduRemarkLanguage.english,
          inputs: ReportRemarkInputs(
            attendancePercent: 90,
            averageMarks: 75,
            strengths: ['participation'],
            weaknesses: [],
            activities: [],
          ),
        ),
      );
      expect(remark.status, 'draft');

      final published = await repo.publishReportRemark(
        query: query,
        remarkId: remark.id,
      );
      expect(published.status, 'published');
    });
  });
}
