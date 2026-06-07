import 'package:akshara_erp/core/repositories/api/parent/api_parent_repository.dart';
import 'package:akshara_erp/core/repositories/api/parent/remote/parent_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/parent/remote/parent_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/mobile/parent_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = ParentFixtureBuilder();

void main() {
  group('Parent API integration', () {
    late MockParentRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUp(() async {
      mockRepo = MockParentRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final attendance = await mockRepo.getAttendance(
        query: kQuery,
        month: DateTime(2026, 6, 1),
      );
      final homework = await mockRepo.getHomework(query: kQuery);
      final exams = await mockRepo.getExams(query: kQuery);
      final timetable = await mockRepo.getTimetable(query: kQuery);
      final fees = await mockRepo.getFees(query: kQuery);
      final receipts = await mockRepo.getReceipts(query: kQuery);
      final notices = await mockRepo.getNotices(query: kQuery);
      final events = await mockRepo.getEvents(query: kQuery);
      final leave = await mockRepo.getLeaveHistory(query: kQuery);
      final profile = await mockRepo.getProfile(
        query: kQuery,
        activeChildId: 'child_ravi',
      );
      final payment = await mockRepo.getPaymentSummary(
        query: kQuery,
        installmentId: 'term_2',
      );

      responseForPath = (path) => switch (path) {
            ParentApiPaths.dashboard => _fixtures.dashboardEnvelope(dashboard),
            ParentApiPaths.attendance => _fixtures.attendanceEnvelope(attendance),
            ParentApiPaths.homework => _fixtures.homeworkEnvelope(homework),
            ParentApiPaths.exams => _fixtures.examsEnvelope(exams),
            ParentApiPaths.timetable => _fixtures.timetableEnvelope(timetable),
            ParentApiPaths.fees => _fixtures.feesEnvelope(fees),
            ParentApiPaths.receipts => _fixtures.listEnvelope([
                for (final receipt in receipts) _fixtures.receiptItem(receipt),
              ]),
            ParentApiPaths.notices => _fixtures.listEnvelope([
                for (final notice in notices) _fixtures.noticeItem(notice),
              ]),
            ParentApiPaths.events => _fixtures.eventsEnvelope(events),
            ParentApiPaths.leave => _fixtures.listEnvelope([
                for (final request in leave) _fixtures.leaveItem(request),
              ]),
            ParentApiPaths.profile => _fixtures.profileEnvelope(profile),
            _ when path.startsWith('${ParentApiPaths.base}/payments/') =>
              _fixtures.paymentSummaryEnvelope(payment),
            _ => const {'data': {}},
          };
    });

    test('remote datasource fetches all Parent read endpoints', () async {
      final remote = ParentRemoteDataSource(
        createFakeDio((options) => responseForPath(options.path)),
      );

      expect((await remote.fetchDashboard(query: kQuery)).raw['childName'], isNotNull);
      expect((await remote.fetchAttendance(
        query: kQuery,
        month: DateTime(2026, 6, 1),
      )).raw['kpi'], isNotNull);
      expect((await remote.fetchHomework(query: kQuery)).raw['items'], isNotNull);
      expect((await remote.fetchExams(query: kQuery)).raw['upcomingExams'], isNotNull);
      expect((await remote.fetchTimetable(query: kQuery)).raw['days'], isNotNull);
      expect((await remote.fetchFees(query: kQuery)).raw['pendingAmount'], isNotNull);
      expect((await remote.fetchReceipts(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchNotices(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchEvents(query: kQuery)).raw['upcomingEvents'], isNotNull);
      expect((await remote.fetchLeaveHistory(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchProfile(
        query: kQuery,
        activeChildId: 'child_ravi',
      )).raw['children'], isNotNull);
      expect((await remote.fetchPaymentSummary(
        query: kQuery,
        installmentId: 'term_2',
      )).raw['installmentId'], 'term_2');
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiParentRepository(
        remote: ParentRemoteDataSource(
          createFakeDio((options) => responseForPath(options.path)),
        ),
      );

      final mockData = await mockRepo.getDashboard(query: kQuery);
      final apiData = await repository.getDashboard(query: kQuery);

      expect(apiData.childName, mockData.childName);
      expect(apiData.quickActions.length, mockData.quickActions.length);
    });

    test('provider chain loads dashboard in api mode', () async {
      await initProviderTestPrefs();
      final container = createProviderTestContainer(
        apiParentDio: createFakeDio((options) => responseForPath(options.path)),
        parentApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data = await container.read(parentDashboardFutureProvider.future);
      expect(data.childName, isNotEmpty);
    });
  });
}
