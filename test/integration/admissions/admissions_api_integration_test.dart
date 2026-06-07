import 'package:akshara_erp/core/repositories/api/admissions/api_admissions_repository.dart';
import 'package:akshara_erp/features/admissions/dashboard/admissions_dashboard_provider.dart';
import 'package:akshara_erp/core/repositories/api/admissions/remote/admissions_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/admissions/remote/admissions_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/admissions/admissions_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = AdmissionsFixtureBuilder();

void main() {
  group('Admissions API integration', () {
    late MockAdmissionsRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUp(() async {
      mockRepo = MockAdmissionsRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final leads = await mockRepo.getLeads(query: kQuery);
      final applications = await mockRepo.getApplications(query: kQuery);
      final documents = await mockRepo.getDocuments(query: kQuery);
      final enrollments = await mockRepo.getPendingEnrollments(query: kQuery);
      final handoffs = await mockRepo.getApprovedHandoffs(query: kQuery);
      final feeStructures = await mockRepo.getFeeStructureOptions(query: kQuery);
      final approvalQueue = await mockRepo.getApprovalQueue(query: kQuery);
      final reports = await mockRepo.getReports(query: kQuery);
      final settings = await mockRepo.getSettings(query: kQuery);
      final prefill = await mockRepo.getEnrollmentPrefill(query: kQuery);

      responseForPath = (path) => switch (path) {
            AdmissionsApiPaths.dashboard =>
              _fixtures.dashboardEnvelope(dashboard),
            AdmissionsApiPaths.leads => _fixtures.listEnvelope([
                for (final lead in leads.items) _fixtures.leadItem(lead),
              ]),
            AdmissionsApiPaths.applications => _fixtures.listEnvelope([
                for (final app in applications.items) _fixtures.applicationItem(app),
              ]),
            AdmissionsApiPaths.documents => _fixtures.listEnvelope([
                for (final doc in documents) _fixtures.documentItem(doc),
              ]),
            AdmissionsApiPaths.enrollmentsPending => _fixtures.listEnvelope([
                for (final record in enrollments)
                  _fixtures.enrollmentItem(record),
              ]),
            AdmissionsApiPaths.handoffsApproved => _fixtures.listEnvelope([
                for (final handoff in handoffs)
                  _fixtures.handoffItem(handoff),
              ]),
            AdmissionsApiPaths.feeStructures => _fixtures.listEnvelope([
                for (final option in feeStructures)
                  _fixtures.feeStructureItem(option),
              ]),
            AdmissionsApiPaths.approvalQueue => _fixtures.listEnvelope([
                for (final item in approvalQueue.items) _fixtures.approvalItem(item),
              ]),
            AdmissionsApiPaths.reports =>
              _fixtures.reportsEnvelope(reports),
            AdmissionsApiPaths.settings =>
              _fixtures.settingsEnvelope(settings),
            AdmissionsApiPaths.enrollmentPrefill =>
              _fixtures.enrollmentPrefillEnvelope(prefill),
            _ => {'data': {}},
          };
    });

    test('remote datasource fetches all admissions endpoints', () async {
      final dio = createFakeDio(
        (options) => responseForPath(options.path),
      );
      final remote = AdmissionsRemoteDataSource(dio);

      final dashboard = await remote.fetchDashboard(query: kQuery);
      expect(dashboard.raw['kpis'], isNotNull);

      final leads = await remote.fetchLeads(query: kQuery);
      expect(leads.items, isNotEmpty);

      final applications = await remote.fetchApplications(query: kQuery);
      expect(applications.items.length, 6);

      final documents = await remote.fetchDocuments(query: kQuery);
      expect(documents.items, isNotEmpty);

      final enrollments = await remote.fetchPendingEnrollments(query: kQuery);
      expect(enrollments.items.length, 3);

      final handoffs = await remote.fetchApprovedHandoffs(query: kQuery);
      expect(handoffs.items.length, 3);

      final feeStructures = await remote.fetchFeeStructureOptions(query: kQuery);
      expect(feeStructures.items.length, 3);

      final approval = await remote.fetchApprovalQueue(query: kQuery);
      expect(approval.items.length, 3);

      final reports = await remote.fetchReports(query: kQuery);
      expect(reports.raw['funnelSegments'], isNotNull);

      final settings = await remote.fetchSettings(query: kQuery);
      expect(settings.raw['leadStages'], isNotNull);

      final prefill = await remote.fetchEnrollmentPrefill(query: kQuery);
      expect(prefill.raw['student'], isNotNull);
    });

    test('provider to repository to remote returns domain models', () async {
      final dio = createFakeDio(
        (options) => responseForPath(options.path),
      );
      final apiRepo = ApiAdmissionsRepository(
        remote: AdmissionsRemoteDataSource(dio),
      );

      final mockLeads = await mockRepo.getLeads(query: kQuery);
      final apiLeads = await apiRepo.getLeads(query: kQuery);

      expect(apiLeads.items.length, mockLeads.items.length);
      expect(
        apiLeads.items.map((l) => l.id).toList(),
        mockLeads.items.map((l) => l.id).toList(),
      );
    });

    test('admissions dashboard provider loads via API repository', () async {
      final dio = createFakeDio(
        (options) => responseForPath(options.path),
      );

      final container = createProviderTestContainer(
        apiAdmissionsDio: dio,
        admissionsApiEnabled: true,
      );
      addTearDown(container.dispose);

      final dashboard = await container.read(
        admissionsDashboardFutureProvider.future,
      );

      expect(dashboard.kpis, hasLength(6));
      expect(dashboard.pipeline, hasLength(7));
    });
  });
}
