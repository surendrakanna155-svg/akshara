import 'package:akshara_erp/features/platform/control_center/control_center_models.dart';
import 'package:akshara_erp/features/platform/control_center/control_center_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = createProviderTestContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('Control Center providers', () {
    test('controlCenterDashboardProvider returns dashboard data', () async {      await container.read(controlCenterDashboardFutureProvider.future);

      final data = container.read(controlCenterDashboardProvider);

      expect(data, isNotNull);
      expect(data!.kpis, hasLength(7));
      expect(data.erpModules, hasLength(7));
    });

    test('controlCenterDashboardProvider returns null when loading', () async {
      container = createProviderTestContainer(
        overrides: [
          controlCenterDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );

      expect(container.read(controlCenterDashboardProvider), isNull);
    });

    test('controlCenterSchoolsProvider returns schools', () async {      await container.read(controlCenterSchoolsFutureProvider.future);

      final schools = container.read(controlCenterSchoolsProvider);

      expect(schools, isNotNull);
      expect(schools!, hasLength(5));
    });

    test('controlCenterFilteredSchoolsProvider filters active schools', () async {
      container = createProviderTestContainer(
        overrides: [
          controlCenterSchoolsFilterProvider.overrideWith((ref) => 1),
        ],
      );

      final filtered = container.read(controlCenterFilteredSchoolsProvider);
      expect(
        filtered.every((s) => s.status == PlatformSchoolStatus.active),
        isTrue,
      );
    });

    test('controlCenterSubscriptionsProvider returns plans', () async {      await container.read(controlCenterSubscriptionsFutureProvider.future);

      final data = container.read(controlCenterSubscriptionsProvider);

      expect(data, isNotNull);
      expect(data!.plans, hasLength(3));
    });

    test('controlCenterBillingProvider returns billing data', () async {      await container.read(controlCenterBillingFutureProvider.future);

      final data = container.read(controlCenterBillingProvider);

      expect(data, isNotNull);
      expect(data!.invoices, hasLength(3));
    });

    test('controlCenterCrmProvider returns CRM pipeline', () async {      await container.read(controlCenterCrmFutureProvider.future);

      final data = container.read(controlCenterCrmProvider);

      expect(data, isNotNull);
      expect(data!.deals, hasLength(4));
    });

    test('controlCenterSupportProvider returns support tickets', () async {      await container.read(controlCenterSupportFutureProvider.future);

      final tickets = container.read(controlCenterSupportProvider);

      expect(tickets, isNotNull);
      expect(tickets!, hasLength(3));
    });

    test('controlCenterFilteredSupportProvider filters open tickets', () async {
      container = createProviderTestContainer(
        overrides: [
          controlCenterSupportFilterProvider.overrideWith((ref) => 1),
        ],
      );

      final filtered = container.read(controlCenterFilteredSupportProvider);
      expect(
        filtered.every((t) => t.status == SupportTicketStatus.open),
        isTrue,
      );
    });

    test('controlCenterSuccessProvider returns customer success data', () async {      await container.read(controlCenterSuccessFutureProvider.future);

      final data = container.read(controlCenterSuccessProvider);

      expect(data, isNotNull);
      expect(data!.schools, hasLength(3));
    });

    test('controlCenterWhiteLabelProvider returns white label configs', () async {      await container.read(controlCenterWhiteLabelFutureProvider.future);

      final configs = container.read(controlCenterWhiteLabelProvider);

      expect(configs, isNotNull);
      expect(configs!, hasLength(3));
    });

    test('controlCenterAnalyticsProvider returns analytics data', () async {      await container.read(controlCenterAnalyticsFutureProvider.future);

      final data = container.read(controlCenterAnalyticsProvider);

      expect(data, isNotNull);
      expect(data!.moduleUsage, hasLength(4));
    });

    test('controlCenterMonitoringProvider returns monitoring data', () async {      await container.read(controlCenterMonitoringFutureProvider.future);

      final data = container.read(controlCenterMonitoringProvider);

      expect(data, isNotNull);
      expect(data!.services, hasLength(4));
    });

    test('controlCenterRolesProvider returns roles data', () async {      await container.read(controlCenterRolesFutureProvider.future);

      final data = container.read(controlCenterRolesProvider);

      expect(data, isNotNull);
      expect(data!.roles, hasLength(4));
    });

    test('controlCenterSettingsProvider returns settings sections', () async {      await container.read(controlCenterSettingsFutureProvider.future);

      final data = container.read(controlCenterSettingsProvider);

      expect(data, isNotNull);
      expect(data!.sections.length, greaterThan(2));
    });
  });
}
