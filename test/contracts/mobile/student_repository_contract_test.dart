import 'package:akshara_erp/core/repositories/api/api_exception.dart';
import 'package:akshara_erp/core/repositories/api/student/api_student_repository.dart';
import 'package:akshara_erp/core/repositories/interfaces/student_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

const kQuery = RepositoryQuery.demo;

void main() {
  group('Student repository contract', () {
    late MockStudentRepository mockRepo;
    late ApiStudentRepository apiRepo;

    setUp(() {
      mockRepo = MockStudentRepository();
      apiRepo = ApiStudentRepository();
    });

    test('mock and api implement StudentRepository', () {
      expect(mockRepo, isA<StudentRepository>());
      expect(apiRepo, isA<StudentRepository>());
    });

    test('getDashboard returns student dashboard data', () async {
      final data = await mockRepo.getDashboard(query: kQuery);
      expect(data.studentName, isNotEmpty);
      expect(data.todaySchedule, isNotEmpty);
    });

    test('getAttendance returns month data', () async {
      final data = await mockRepo.getAttendance(
        query: kQuery,
        month: DateTime(2026, 6, 1),
      );
      expect(data.kpi.attendancePercent, greaterThan(0));
    });

    test('getHomeworkItems returns items', () async {
      final items = await mockRepo.getHomeworkItems(query: kQuery);
      expect(items, isNotEmpty);
    });

    test('getExams returns exam data', () async {
      final data = await mockRepo.getExams(query: kQuery);
      expect(data.upcomingExams, isNotEmpty);
    });

    test('getNotices returns notices', () async {
      final notices = await mockRepo.getNotices(query: kQuery);
      expect(notices, isNotEmpty);
    });

    test('api getDashboard throws ApiNotConnectedException', () async {
      await expectLater(
        apiRepo.getDashboard(query: kQuery),
        throwsA(isA<ApiNotConnectedException>()),
      );
    });
  });
}
