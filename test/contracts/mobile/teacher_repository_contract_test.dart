import 'package:akshara_erp/core/repositories/api/api_exception.dart';
import 'package:akshara_erp/core/repositories/api/teacher/api_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/interfaces/teacher_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

const kQuery = RepositoryQuery.demo;

void main() {
  group('Teacher repository contract', () {
    late MockTeacherRepository mockRepo;
    late ApiTeacherRepository apiRepo;

    setUp(() {
      mockRepo = MockTeacherRepository();
      apiRepo = ApiTeacherRepository();
    });

    test('mock and api implement TeacherRepository', () {
      expect(mockRepo, isA<TeacherRepository>());
      expect(apiRepo, isA<TeacherRepository>());
    });

    test('getDashboard returns teacher dashboard data', () async {
      final data = await mockRepo.getDashboard(query: kQuery);
      expect(data.teacherName, isNotEmpty);
      expect(data.todaySchedule, isNotEmpty);
    });

    test('getAttendanceClasses returns classes', () async {
      final classes = await mockRepo.getAttendanceClasses(query: kQuery);
      expect(classes, isNotEmpty);
    });

    test('getHomeworkAssignments returns assignments', () async {
      final assignments = await mockRepo.getHomeworkAssignments(query: kQuery);
      expect(assignments, isNotEmpty);
    });

    test('getExamMarks returns mark entries', () async {
      final marks = await mockRepo.getExamMarks(query: kQuery);
      expect(marks, isNotEmpty);
    });

    test('getMessageThreads returns threads', () async {
      final threads = await mockRepo.getMessageThreads(query: kQuery);
      expect(threads, isNotEmpty);
    });

    test('api getDashboard throws ApiNotConnectedException', () async {
      await expectLater(
        apiRepo.getDashboard(query: kQuery),
        throwsA(isA<ApiNotConnectedException>()),
      );
    });
  });
}
