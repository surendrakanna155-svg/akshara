import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/repositories/api/phase4/api_phase4_repositories.dart';
import 'package:akshara_erp/core/repositories/mock/mock_employee_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_homework_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_distribution_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_360_repository.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;

  group('Phase 4 mock repositories', () {
    test('homework intelligence returns plan with risk students', () async {
      final repo = MockHomeworkIntelligenceRepository();
      final plan = await repo.getPlan(
        query: query,
        className: 'Grade 8',
        subjectName: 'Mathematics',
      );
      expect(plan.weakTopics, isNotEmpty);
      expect(plan.riskStudents, isNotEmpty);
    });

    test('student 360 profile and timeline', () async {
      final repo = MockStudent360Repository();
      final profile = await repo.getProfile(query: query, studentId: 'student_1');
      expect(profile.identity['displayName'], isNotNull);
      final timeline = await repo.getTimeline(query: query, studentId: 'student_1');
      expect(timeline, isNotEmpty);
    });

    test('employee platform dashboard and roles', () async {
      final repo = MockEmployeeRepository();
      final dashboard = await repo.getDashboard(query: query);
      expect(dashboard.totalEmployees, greaterThan(0));
      final detail = await repo.getEmployee(query: query, employeeId: 'emp_1');
      expect(detail.roles, isNotEmpty);
    });

    test('inventory distribution lifecycle', () async {
      final repo = MockInventoryDistributionRepository();
      final dashboard = await repo.getDashboard(query: query);
      expect(dashboard.pendingDistributions, greaterThanOrEqualTo(0));
      final created = await repo.createDistribution(
        query: query,
        studentId: 'student_3',
        catalogItemId: 'cat_1',
      );
      expect(created.status, 'available');
    });
  });

  group('Phase 4 repository providers', () {
    test('employee uses API when flag enabled', () {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: true),
          ),
          employeeApiEnabledProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(employeeRepositoryProvider), isA<ApiEmployeeRepository>());
    });

    test('homework intelligence uses mock by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(homeworkIntelligenceRepositoryProvider),
        isA<MockHomeworkIntelligenceRepository>(),
      );
    });
  });
}
