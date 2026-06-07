import 'package:akshara_erp/core/repositories/api/teacher/api_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/api/teacher/remote/teacher_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/teacher/remote/teacher_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/teacher/dashboard/teacher_dashboard_provider.dart';
import 'package:akshara_erp/features/teacher/leave/leave_models.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/mobile/teacher_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = TeacherFixtureBuilder();

void main() {
  group('Teacher API integration', () {
    late MockTeacherRepository mockRepo;
    late TeacherLeaveRequest submittedLeave;
    late Map<String, dynamic> Function(RequestOptions options) responseForRequest;

    setUp(() async {
      mockRepo = MockTeacherRepository();
      submittedLeave = await mockRepo.submitLeaveRequest(
        query: kQuery,
        request: const TeacherLeaveSubmitRequest(
          typeLabel: 'Casual leave',
          fromDateLabel: '18 Jun 2026',
          toDateLabel: '18 Jun 2026',
          reason: 'Personal appointment in the afternoon.',
        ),
      );
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final classes = await mockRepo.getAttendanceClasses(query: kQuery);
      final students = await mockRepo.getAttendanceStudentsByClass(query: kQuery);
      final homework = await mockRepo.getHomeworkAssignments(query: kQuery);
      final exams = await mockRepo.getUpcomingExams(query: kQuery);
      final marks = await mockRepo.getExamMarks(query: kQuery);
      final timetable = await mockRepo.getTimetable(query: kQuery);
      final leave = await mockRepo.getLeaveHistory(query: kQuery);
      final balance = await mockRepo.getLeaveBalance(query: kQuery);
      final messages = await mockRepo.getMessageThreads(query: kQuery);

      responseForRequest = (options) {
        final path = options.path;
        if (options.method == 'POST' && path == TeacherApiPaths.leave) {
          return _fixtures.envelope(_fixtures.leaveItem(submittedLeave));
        }
        return switch (path) {
            TeacherApiPaths.dashboard => _fixtures.dashboardEnvelope(dashboard),
            TeacherApiPaths.attendanceClasses => _fixtures.listEnvelope([
                for (final item in classes) _fixtures.attendanceClassItem(item),
              ]),
            TeacherApiPaths.attendanceStudents =>
              _fixtures.attendanceStudentsEnvelope(students),
            TeacherApiPaths.homework => _fixtures.listEnvelope([
                for (final item in homework)
                  _fixtures.homeworkAssignmentItem(item),
              ]),
            TeacherApiPaths.examsUpcoming => _fixtures.listEnvelope([
                for (final exam in exams) _fixtures.upcomingExamItem(exam),
              ]),
            TeacherApiPaths.examsMarks => _fixtures.listEnvelope([
                for (final mark in marks) _fixtures.examMarkItem(mark),
              ]),
            TeacherApiPaths.timetable => _fixtures.timetableEnvelope(timetable),
            TeacherApiPaths.leave => _fixtures.listEnvelope([
                for (final request in leave) _fixtures.leaveItem(request),
              ]),
            TeacherApiPaths.leaveBalance =>
              _fixtures.leaveBalanceEnvelope(balance),
            TeacherApiPaths.messages => _fixtures.listEnvelope([
                for (final thread in messages)
                  _fixtures.messageThreadItem(thread),
              ]),
            _ => const {'data': {}},
          };
      };
    });

    test('remote datasource fetches all Teacher read endpoints', () async {
      final remote = TeacherRemoteDataSource(createFakeDio(responseForRequest));

      expect((await remote.fetchDashboard(query: kQuery)).raw['teacherName'], isNotNull);
      expect((await remote.fetchAttendanceClasses(query: kQuery)).items, isNotEmpty);
      expect(
        (await remote.fetchAttendanceStudentsByClass(query: kQuery)).raw['studentsByClass'],
        isNotNull,
      );
      expect((await remote.fetchHomeworkAssignments(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchUpcomingExams(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchExamMarks(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchTimetable(query: kQuery)).raw['days'], isNotNull);
      expect((await remote.fetchLeaveHistory(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchLeaveBalance(query: kQuery)).raw['casualRemaining'], isNotNull);
      expect((await remote.fetchMessageThreads(query: kQuery)).items, isNotEmpty);
    });

    test('remote datasource posts teacher leave submit endpoint', () async {
      final remote = TeacherRemoteDataSource(createFakeDio(responseForRequest));
      final dto = await remote.submitLeaveRequest(
        query: kQuery,
        request: const TeacherLeaveSubmitRequest(
          typeLabel: 'Casual leave',
          fromDateLabel: '18 Jun 2026',
          toDateLabel: '18 Jun 2026',
          reason: 'Personal appointment in the afternoon.',
        ),
      );
      expect(dto.raw['id'], submittedLeave.id);
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiTeacherRepository(
        remote: TeacherRemoteDataSource(createFakeDio(responseForRequest)),
      );

      final mockData = await mockRepo.getDashboard(query: kQuery);
      final apiData = await repository.getDashboard(query: kQuery);

      expect(apiData.teacherName, mockData.teacherName);
      expect(apiData.todaySchedule.length, mockData.todaySchedule.length);
    });

    test('provider chain loads dashboard in api mode', () async {
      await initProviderTestPrefs();
      final container = createProviderTestContainer(
        apiTeacherDio: createFakeDio(responseForRequest),
        teacherApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data = await container.read(teacherDashboardFutureProvider.future);
      expect(data.teacherName, isNotEmpty);
    });
  });
}
