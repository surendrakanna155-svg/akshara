import 'package:akshara_erp/core/repositories/api/control_center/api_control_center_repository.dart';
import 'package:akshara_erp/core/repositories/api/control_center/remote/control_center_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/control_center/remote/control_center_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_control_center_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/control_center/control_center_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/control_center/control_center_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = ControlCenterFixtureBuilder();

void main() {
  group('Control Center API integration', () {
    late MockControlCenterRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUp(() async {
      mockRepo = MockControlCenterRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final schools = await mockRepo.getSchools(query: kQuery);
      final subscriptions = await mockRepo.getSubscriptions(query: kQuery);
      final billing = await mockRepo.getBilling(query: kQuery);
      final crm = await mockRepo.getCrmPipeline(query: kQuery);
      final supportTickets = await mockRepo.getSupportTickets(query: kQuery);
      final customerSuccess = await mockRepo.getCustomerSuccess(query: kQuery);
      final whiteLabel = await mockRepo.getWhiteLabelConfigs(query: kQuery);
      final analytics = await mockRepo.getAnalytics(query: kQuery);
      final monitoring = await mockRepo.getMonitoring(query: kQuery);
      final roles = await mockRepo.getRoles(query: kQuery);
      final settings = await mockRepo.getSettings(query: kQuery);

      responseForPath = (path) => switch (path) {
            ControlCenterApiPaths.dashboard =>
              _fixtures.dashboardEnvelope(dashboard),
            ControlCenterApiPaths.schools => _fixtures.listEnvelope([
                for (final school in schools.items) _fixtures.schoolItem(school),
              ]),
            ControlCenterApiPaths.subscriptions =>
              _fixtures.subscriptionsEnvelope(subscriptions),
            ControlCenterApiPaths.billing => _fixtures.billingEnvelope(billing),
            ControlCenterApiPaths.crmPipeline => _fixtures.crmEnvelope(crm),
            ControlCenterApiPaths.supportTickets => _fixtures.listEnvelope([
                for (final ticket in supportTickets.items)
                  _fixtures.supportTicketItem(ticket),
              ]),
            ControlCenterApiPaths.customerSuccess =>
              _fixtures.customerSuccessEnvelope(customerSuccess),
            ControlCenterApiPaths.whiteLabel => _fixtures.listEnvelope([
                for (final config in whiteLabel.items)
                  _fixtures.whiteLabelItem(config),
              ]),
            ControlCenterApiPaths.analytics =>
              _fixtures.analyticsEnvelope(analytics),
            ControlCenterApiPaths.monitoring =>
              _fixtures.monitoringEnvelope(monitoring),
            ControlCenterApiPaths.roles => _fixtures.rolesEnvelope(roles),
            ControlCenterApiPaths.settings =>
              _fixtures.settingsEnvelope(settings),
            _ => const {'data': {}},
          };
    });

    test('remote datasource fetches all Control Center read endpoints', () async {
      final remote = ControlCenterRemoteDataSource(
        createFakeDio((options) => responseForPath(options.path)),
      );

      expect((await remote.fetchDashboard(query: kQuery)).raw['kpis'], isNotNull);
      expect((await remote.fetchSchools(query: kQuery)).items, isNotEmpty);
      expect(
        (await remote.fetchSubscriptions(query: kQuery)).raw['plans'],
        isNotNull,
      );
      expect((await remote.fetchBilling(query: kQuery)).raw['invoices'], isNotNull);
      expect((await remote.fetchCrmPipeline(query: kQuery)).raw['deals'], isNotNull);
      expect((await remote.fetchSupportTickets(query: kQuery)).items, isNotEmpty);
      expect(
        (await remote.fetchCustomerSuccess(query: kQuery)).raw['schools'],
        isNotNull,
      );
      expect((await remote.fetchWhiteLabelConfigs(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchAnalytics(query: kQuery)).raw['moduleUsage'], isNotNull);
      expect((await remote.fetchMonitoring(query: kQuery)).raw['services'], isNotNull);
      expect((await remote.fetchRoles(query: kQuery)).raw['roles'], isNotNull);
      expect((await remote.fetchSettings(query: kQuery)).raw['sections'], isNotNull);
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiControlCenterRepository(
        remote: ControlCenterRemoteDataSource(
          createFakeDio((options) => responseForPath(options.path)),
        ),
      );

      final mockData = await mockRepo.getDashboard(query: kQuery);
      final apiData = await repository.getDashboard(query: kQuery);

      expect(apiData.kpis.length, mockData.kpis.length);
      expect(apiData.aiInsight, mockData.aiInsight);
    });

    test('provider chain loads dashboard in api mode', () async {
      await initProviderTestPrefs();
      final container = createProviderTestContainer(
        apiControlCenterDio:
            createFakeDio((options) => responseForPath(options.path)),
        controlCenterApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data =
          await container.read(controlCenterDashboardFutureProvider.future);
      expect(data.kpis, isNotEmpty);
    });
  });
}
