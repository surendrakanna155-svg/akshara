import 'package:akshara_erp/core/repositories/api/alumni/api_alumni_repository.dart';
import 'package:akshara_erp/core/repositories/api/alumni/remote/alumni_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/alumni/remote/alumni_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_alumni_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/alumni/alumni_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/alumni/alumni_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = AlumniFixtureBuilder();

void main() {
  group('Alumni API integration', () {
    late MockAlumniRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUp(() async {
      mockRepo = MockAlumniRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final registry = await mockRepo.getAlumniRegistry(query: kQuery);
      final detail = await mockRepo.getAlumniDetail(
        query: kQuery,
        alumniId: registry.first.id,
      );
      final events = await mockRepo.getEvents(query: kQuery);
      final donations = await mockRepo.getDonations(query: kQuery);
      final campaigns = await mockRepo.getCampaigns(query: kQuery);
      final mentorship = await mockRepo.getMentorshipPairs(query: kQuery);
      final reports = await mockRepo.getReports(query: kQuery);
      final settings = await mockRepo.getSettings(query: kQuery);

      responseForPath = (path) => switch (path) {
            AlumniApiPaths.dashboard => _fixtures.dashboardEnvelope(dashboard),
            AlumniApiPaths.registry => _fixtures.listEnvelope([
                for (final record in registry) _fixtures.recordItem(record),
              ]),
            AlumniApiPaths.events => _fixtures.listEnvelope([
                for (final event in events) _fixtures.eventItem(event),
              ]),
            AlumniApiPaths.donations => _fixtures.listEnvelope([
                for (final donation in donations)
                  _fixtures.donationItem(donation),
              ]),
            AlumniApiPaths.campaigns => _fixtures.listEnvelope([
                for (final campaign in campaigns)
                  _fixtures.campaignItem(campaign),
              ]),
            AlumniApiPaths.mentorship => _fixtures.listEnvelope([
                for (final pair in mentorship)
                  _fixtures.mentorshipPairItem(pair),
              ]),
            AlumniApiPaths.reports => _fixtures.reportsEnvelope(reports),
            AlumniApiPaths.settings => _fixtures.settingsEnvelope(settings),
            _ when path.startsWith('${AlumniApiPaths.registry}/') =>
              _fixtures.alumniDetailEnvelope(detail!),
            _ => const {'data': {}},
          };
    });

    test('remote datasource fetches all Alumni read endpoints', () async {
      final remote = AlumniRemoteDataSource(
        createFakeDio((options) => responseForPath(options.path)),
      );

      expect((await remote.fetchDashboard(query: kQuery)).raw['kpis'], isNotNull);
      expect((await remote.fetchRegistry(query: kQuery)).items, isNotEmpty);
      expect(
        await remote.fetchAlumniDetail(query: kQuery, alumniId: 'ALM-001'),
        isNotNull,
      );
      expect((await remote.fetchEvents(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchDonations(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchCampaigns(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchMentorshipPairs(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchReports(query: kQuery)).raw['catalog'], isNotNull);
      expect((await remote.fetchSettings(query: kQuery)).raw['sections'], isNotNull);
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiAlumniRepository(
        remote: AlumniRemoteDataSource(
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
        apiAlumniDio: createFakeDio((options) => responseForPath(options.path)),
        alumniApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data = await container.read(alumniDashboardFutureProvider.future);
      expect(data.kpis, isNotEmpty);
    });
  });
}
