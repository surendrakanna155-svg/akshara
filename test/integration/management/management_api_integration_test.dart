import 'package:akshara_erp/core/repositories/api/management/api_management_repository.dart';
import 'package:akshara_erp/core/repositories/api/management/remote/management_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/management/remote/management_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_management_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/management/management_requests.dart';
import 'package:akshara_erp/features/management/management_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/management/management_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = ManagementFixtureBuilder();

void main() {
  group('Management API integration', () {
    late MockManagementRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUp(() async {
      mockRepo = MockManagementRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final analytics = await mockRepo.getAnalytics(query: kQuery);
      final admissionsFunnel =
          await mockRepo.getAdmissionsFunnel(query: kQuery);
      final financialHealth = await mockRepo.getFinancialHealth(query: kQuery);
      final academicHealth = await mockRepo.getAcademicHealth(query: kQuery);
      final schoolPerformance =
          await mockRepo.getSchoolPerformance(query: kQuery);
      final tasks = await mockRepo.getTasksAndApprovals(query: kQuery);
      final settings = await mockRepo.getSettings(query: kQuery);

      responseForPath = (path) => switch (path) {
            ManagementApiPaths.dashboard =>
              _fixtures.dashboardEnvelope(dashboard),
            ManagementApiPaths.analytics =>
              _fixtures.analyticsEnvelope(analytics),
            ManagementApiPaths.admissionsFunnel =>
              _fixtures.admissionsFunnelEnvelope(admissionsFunnel),
            ManagementApiPaths.financialHealth =>
              _fixtures.financialHealthEnvelope(financialHealth),
            ManagementApiPaths.academicHealth =>
              _fixtures.academicHealthEnvelope(academicHealth),
            ManagementApiPaths.schoolPerformance =>
              _fixtures.schoolPerformanceEnvelope(schoolPerformance),
            ManagementApiPaths.tasks => _fixtures.tasksEnvelope(tasks),
            ManagementApiPaths.settings => _fixtures.settingsEnvelope(settings),
            _ => const {'data': {}},
          };
    });

    test('remote datasource fetches all Management read endpoints', () async {
      final remote = ManagementRemoteDataSource(
        createFakeDio((options) => responseForPath(options.path)),
      );

      expect(
          (await remote.fetchDashboard(query: kQuery)).raw['kpis'], isNotNull);
      expect((await remote.fetchAnalytics(query: kQuery)).raw['classSummary'],
          isNotNull);
      expect(
        (await remote.fetchAdmissionsFunnel(query: kQuery)).raw['funnelStages'],
        isNotNull,
      );
      expect(
        (await remote.fetchFinancialHealth(query: kQuery)).raw['drillLinks'],
        isNotNull,
      );
      expect(
        (await remote.fetchAcademicHealth(query: kQuery)).raw['metrics'],
        isNotNull,
      );
      expect(
        (await remote.fetchSchoolPerformance(query: kQuery))
            .raw['classPerformance'],
        isNotNull,
      );
      expect(
          (await remote.fetchTasksAndApprovals(query: kQuery)).raw['approvals'],
          isNotNull);
      expect((await remote.fetchSettings(query: kQuery)).raw['sections'],
          isNotNull);
      expect(
        (await remote.updateSettings(
          query: kQuery,
          request: const UpdateManagementSettingsRequest(
            updates: [
              ManagementSettingUpdate(
                sectionId: 'school',
                itemId: 'name',
                value: 'Updated School',
              ),
            ],
          ),
        ))
            .raw['sections'],
        isNotNull,
      );
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiManagementRepository(
        remote: ManagementRemoteDataSource(
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
        apiManagementDio:
            createFakeDio((options) => responseForPath(options.path)),
        managementApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data =
          await container.read(managementDashboardFutureProvider.future);
      expect(data.kpis, isNotEmpty);
    });
  });
}
