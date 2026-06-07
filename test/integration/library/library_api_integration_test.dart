import 'package:akshara_erp/core/repositories/api/library/api_library_repository.dart';
import 'package:akshara_erp/core/repositories/api/library/remote/library_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/library/remote/library_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_library_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/library/library_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/library/library_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = LibraryFixtureBuilder();

void main() {
  group('Library API integration', () {
    late MockLibraryRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUp(() async {
      mockRepo = MockLibraryRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final catalog = await mockRepo.getCatalog(query: kQuery);
      final issues = await mockRepo.getIssues(query: kQuery);
      final returns = await mockRepo.getReturns(query: kQuery);
      final members = await mockRepo.getMembers(query: kQuery);
      final fines = await mockRepo.getFines(query: kQuery);
      final resources = await mockRepo.getDigitalResources(query: kQuery);
      final reports = await mockRepo.getReports(query: kQuery);

      responseForPath = (path) => switch (path) {
            LibraryApiPaths.dashboard => _fixtures.dashboardEnvelope(dashboard),
            LibraryApiPaths.catalog => _fixtures.catalogEnvelope(catalog),
            LibraryApiPaths.issues => _fixtures.issuesEnvelope(issues),
            LibraryApiPaths.returns => _fixtures.returnsEnvelope(returns),
            LibraryApiPaths.members => _fixtures.membersEnvelope(members),
            LibraryApiPaths.fines => _fixtures.finesEnvelope(fines),
            LibraryApiPaths.digitalResources =>
              _fixtures.digitalResourcesEnvelope(resources),
            LibraryApiPaths.reports => _fixtures.reportsEnvelope(reports),
            _ => const {'data': {}},
          };
    });

    test('remote datasource fetches all Library read endpoints', () async {
      final remote = LibraryRemoteDataSource(
        createFakeDio((options) => responseForPath(options.path)),
      );

      expect((await remote.fetchDashboard(query: kQuery)).raw['kpis'], isNotNull);
      expect((await remote.fetchCatalog(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchIssues(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchReturns(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchMembers(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchFines(query: kQuery)).raw['fines'], isNotNull);
      expect(
        (await remote.fetchDigitalResources(query: kQuery)).raw['resources'],
        isNotNull,
      );
      expect((await remote.fetchReports(query: kQuery)).raw['catalog'], isNotNull);
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiLibraryRepository(
        remote: LibraryRemoteDataSource(
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
        apiLibraryDio: createFakeDio((options) => responseForPath(options.path)),
        libraryApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data = await container.read(libraryDashboardFutureProvider.future);
      expect(data.kpis, isNotEmpty);
    });
  });
}
