import 'package:akshara_erp/core/repositories/api/teacher/api_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/api/teacher/dto/teacher_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/teacher/mapper/teacher_mapper.dart';
import 'package:akshara_erp/core/repositories/api/teacher/remote/teacher_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/teacher_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'teacher_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = TeacherFixtureBuilder();
const _mapper = TeacherMapper();

void main() {
  group('Teacher repository contract', () {
    late MockTeacherRepository mockRepo;
    late ApiTeacherRepository apiRepo;

    setUp(() {
      mockRepo = MockTeacherRepository();
      apiRepo = ApiTeacherRepository(
        remote: TeacherRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement TeacherRepository', () {
      expect(mockRepo, isA<TeacherRepository>());
      expect(apiRepo, isA<TeacherRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        TeacherDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );
      expect(mapped.teacherName, mockData.teacherName);
      expect(mapped.todaySchedule.length, mockData.todaySchedule.length);
    });

    test('getAttendanceClasses DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAttendanceClasses(query: kQuery);
      final mapped = _mapper.toAttendanceClasses(
        TeacherAttendanceClassesResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final item in mockData) _fixtures.attendanceClassItem(item),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getAttendanceStudentsByClass DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAttendanceStudentsByClass(query: kQuery);
      final mapped = _mapper.toAttendanceStudentsByClass(
        TeacherAttendanceStudentsResponseDto.fromJson(
          _fixtures.attendanceStudentsEnvelope(mockData),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getHomeworkAssignments DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getHomeworkAssignments(query: kQuery);
      final mapped = _mapper.toHomeworkAssignments(
        TeacherHomeworkResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final item in mockData) _fixtures.homeworkAssignmentItem(item),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getUpcomingExams DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getUpcomingExams(query: kQuery);
      final mapped = _mapper.toUpcomingExams(
        TeacherUpcomingExamsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final exam in mockData) _fixtures.upcomingExamItem(exam),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getExamMarks DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getExamMarks(query: kQuery);
      final mapped = _mapper.toExamMarks(
        TeacherExamMarksResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final mark in mockData) _fixtures.examMarkItem(mark),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getTimetable DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getTimetable(query: kQuery);
      final mapped = _mapper.toTimetable(
        TeacherTimetableResponseDto.fromJson(
          _fixtures.timetableEnvelope(mockData),
        ),
      );
      expect(mapped.days.length, mockData.days.length);
    });

    test('getLeaveHistory DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getLeaveHistory(query: kQuery);
      final mapped = _mapper.toLeaveHistory(
        TeacherLeaveResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final request in mockData) _fixtures.leaveItem(request),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getLeaveBalance DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getLeaveBalance(query: kQuery);
      final mapped = _mapper.toLeaveBalance(
        TeacherLeaveBalanceResponseDto.fromJson(
          _fixtures.leaveBalanceEnvelope(mockData),
        ),
      );
      expect(mapped.casualRemaining, mockData.casualRemaining);
    });

    test('getMessageThreads DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getMessageThreads(query: kQuery);
      final mapped = _mapper.toMessageThreads(
        TeacherMessagesResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final thread in mockData) _fixtures.messageThreadItem(thread),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });
  });
}
