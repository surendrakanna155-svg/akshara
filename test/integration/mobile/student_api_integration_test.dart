import 'package:akshara_erp/core/repositories/api/student/api_student_repository.dart';
import 'package:akshara_erp/core/repositories/api/student/remote/student_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/student/remote/student_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/student/dashboard/student_dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/mobile/student_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = StudentFixtureBuilder();

void main() {
  group('Student API integration', () {
    late MockStudentRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUp(() async {
      mockRepo = MockStudentRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final attendance = await mockRepo.getAttendance(
        query: kQuery,
        month: DateTime(2026, 6, 1),
      );
      final homework = await mockRepo.getHomeworkItems(query: kQuery);
      final exams = await mockRepo.getExams(query: kQuery);
      final timetable = await mockRepo.getTimetable(query: kQuery);
      final notices = await mockRepo.getNotices(query: kQuery);
      final profile = await mockRepo.getProfile(query: kQuery);

      responseForPath = (path) => switch (path) {
            StudentApiPaths.dashboard => _fixtures.dashboardEnvelope(dashboard),
            StudentApiPaths.attendance => _fixtures.attendanceEnvelope(attendance),
            StudentApiPaths.homework => _fixtures.listEnvelope([
                for (final item in homework) _fixtures.homeworkItem(item),
              ]),
            StudentApiPaths.exams => _fixtures.examsEnvelope(exams),
            StudentApiPaths.timetable => _fixtures.timetableEnvelope(timetable),
            StudentApiPaths.notices => _fixtures.listEnvelope([
                for (final notice in notices) _fixtures.noticeItem(notice),
              ]),
            StudentApiPaths.profile => _fixtures.profileEnvelope(profile),
            _ => const {'data': {}},
          };
    });

    test('remote datasource fetches all Student read endpoints', () async {
      final remote = StudentRemoteDataSource(
        createFakeDio((options) => responseForPath(options.path)),
      );

      expect((await remote.fetchDashboard(query: kQuery)).raw['studentName'], isNotNull);
      expect((await remote.fetchAttendance(
        query: kQuery,
        month: DateTime(2026, 6, 1),
      )).raw['kpi'], isNotNull);
      expect((await remote.fetchHomeworkItems(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchExams(query: kQuery)).raw['upcomingExams'], isNotNull);
      expect((await remote.fetchTimetable(query: kQuery)).raw['days'], isNotNull);
      expect((await remote.fetchNotices(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchProfile(query: kQuery)).raw['studentName'], isNotNull);
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiStudentRepository(
        remote: StudentRemoteDataSource(
          createFakeDio((options) => responseForPath(options.path)),
        ),
      );

      final mockData = await mockRepo.getDashboard(query: kQuery);
      final apiData = await repository.getDashboard(query: kQuery);

      expect(apiData.studentName, mockData.studentName);
      expect(apiData.todaySchedule.length, mockData.todaySchedule.length);
    });

    test('provider chain loads dashboard in api mode', () async {
      await initProviderTestPrefs();
      final container = createProviderTestContainer(
        apiStudentDio: createFakeDio((options) => responseForPath(options.path)),
        studentApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data = await container.read(studentDashboardFutureProvider.future);
      expect(data.studentName, isNotEmpty);
    });
  });
}
