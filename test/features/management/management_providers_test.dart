import 'package:akshara_erp/features/management/management_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  group('Management providers', () {
    late ProviderContainer container;

    setUp(() {
      container = createProviderTestContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('managementDashboardProvider returns dashboard data', () async {      await container.read(managementDashboardFutureProvider.future);

      final data = container.read(managementDashboardProvider);
      expect(data, isNotNull);
      expect(data!.kpis, hasLength(6));
      expect(data.approvalQueue, isNotEmpty);
    });

    test('managementDashboardProvider returns null when loading', () async {
      container = createProviderTestContainer(
        overrides: [
          managementDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );
      expect(container.read(managementDashboardProvider), isNull);
    });

    test('managementAnalyticsProvider returns analytics data', () async {      await container.read(managementAnalyticsFutureProvider.future);

      final data = container.read(managementAnalyticsProvider);
      expect(data, isNotNull);
      expect(data!.classSummary, hasLength(3));
    });

    test('managementAdmissionsFunnelProvider returns funnel data', () async {      await container.read(managementAdmissionsFunnelFutureProvider.future);

      final data = container.read(managementAdmissionsFunnelProvider);
      expect(data, isNotNull);
      expect(data!.funnelStages, hasLength(5));
    });

    test('managementFinancialHealthProvider returns finance health data', () async {      await container.read(managementFinancialHealthFutureProvider.future);

      final data = container.read(managementFinancialHealthProvider);
      expect(data, isNotNull);
      expect(data!.drillLinks, hasLength(6));
    });

    test('managementAcademicHealthProvider returns academic data', () async {      await container.read(managementAcademicHealthFutureProvider.future);

      final data = container.read(managementAcademicHealthProvider);
      expect(data, isNotNull);
      expect(data!.atRiskStudents, hasLength(3));
    });

    test('managementSchoolPerformanceProvider returns performance data', () async {      await container.read(managementSchoolPerformanceFutureProvider.future);

      final data = container.read(managementSchoolPerformanceProvider);
      expect(data, isNotNull);
      expect(data!.classPerformance, hasLength(3));
    });

    test('managementTasksProvider returns tasks data', () async {      await container.read(managementTasksFutureProvider.future);

      final data = container.read(managementTasksProvider);
      expect(data, isNotNull);
      expect(data!.approvals.length, greaterThan(5));
    });

    test('managementFilteredApprovalsProvider filters pending', () async {
      container = createProviderTestContainer(
        overrides: [
          managementTasksFilterProvider.overrideWith((ref) => 1),
        ],
      );
      await container.read(managementTasksFutureProvider.future);
      final filtered = container.read(managementFilteredApprovalsProvider);
      expect(filtered, isNotEmpty);
    });

    test('managementSettingsProvider returns settings sections', () async {      await container.read(managementSettingsFutureProvider.future);

      final data = container.read(managementSettingsProvider);
      expect(data, isNotNull);
      expect(data!.sections.length, greaterThanOrEqualTo(4));
    });
  });
}
