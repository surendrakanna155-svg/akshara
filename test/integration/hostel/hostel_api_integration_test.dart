import 'package:akshara_erp/core/repositories/api/hostel/api_hostel_repository.dart';
import 'package:akshara_erp/core/repositories/api/hostel/remote/hostel_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/hostel/remote/hostel_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_hostel_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/hostel/hostel_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/hostel/hostel_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = HostelFixtureBuilder();

void main() {
  group('Hostel API integration', () {
    late MockHostelRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUp(() async {
      mockRepo = MockHostelRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final students = await mockRepo.getStudents(query: kQuery);
      final rooms = await mockRepo.getRooms(query: kQuery);
      final attendance = await mockRepo.getAttendanceRecords(query: kQuery);
      final leave = await mockRepo.getLeaveRequests(query: kQuery);
      final mess = await mockRepo.getMessData(query: kQuery);
      final visitors = await mockRepo.getVisitors(query: kQuery);
      final reports = await mockRepo.getReports(query: kQuery);
      final occupancy = await mockRepo.getOccupancyMetrics(query: kQuery);

      responseForPath = (path) => switch (path) {
            HostelApiPaths.dashboard => _fixtures.dashboardEnvelope(dashboard),
            HostelApiPaths.students => _fixtures.studentsEnvelope(students),
            HostelApiPaths.rooms => _fixtures.roomsEnvelope(rooms),
            HostelApiPaths.attendance =>
              _fixtures.attendanceEnvelope(attendance),
            HostelApiPaths.leave => _fixtures.leaveEnvelope(leave),
            HostelApiPaths.mess => _fixtures.messEnvelope(mess),
            HostelApiPaths.visitors => _fixtures.visitorsEnvelope(visitors),
            HostelApiPaths.reports => _fixtures.reportsEnvelope(reports),
            HostelApiPaths.occupancyMetrics =>
              _fixtures.occupancyMetricsEnvelope(occupancy),
            _ => const {'data': {}},
          };
    });

    test('remote datasource fetches all Hostel read endpoints', () async {
      final remote = HostelRemoteDataSource(
        createFakeDio((options) => responseForPath(options.path)),
      );

      expect((await remote.fetchDashboard(query: kQuery)).raw['kpis'], isNotNull);
      expect((await remote.fetchStudents(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchRooms(query: kQuery)).items, isNotEmpty);
      expect(
        (await remote.fetchAttendanceRecords(query: kQuery)).items,
        isNotEmpty,
      );
      expect((await remote.fetchLeaveRequests(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchMessData(query: kQuery)).raw['weeklyMenus'], isNotNull);
      expect(
        (await remote.fetchVisitors(query: kQuery)).raw['activeVisitors'],
        isNotNull,
      );
      expect((await remote.fetchReports(query: kQuery)).raw['catalog'], isNotNull);
      expect(
        (await remote.fetchOccupancyMetrics(query: kQuery)).raw['totalBeds'],
        isNotNull,
      );
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiHostelRepository(
        remote: HostelRemoteDataSource(
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
        apiHostelDio: createFakeDio((options) => responseForPath(options.path)),
        hostelApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data = await container.read(hostelDashboardFutureProvider.future);
      expect(data.kpis, isNotEmpty);
    });
  });
}
