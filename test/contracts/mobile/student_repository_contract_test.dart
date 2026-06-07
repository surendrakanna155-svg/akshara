import 'package:akshara_erp/core/repositories/api/student/api_student_repository.dart';
import 'package:akshara_erp/core/repositories/api/student/dto/student_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/student/mapper/student_mapper.dart';
import 'package:akshara_erp/core/repositories/api/student/remote/student_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/student_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'student_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = StudentFixtureBuilder();
const _mapper = StudentMapper();

void main() {
  group('Student repository contract', () {
    late MockStudentRepository mockRepo;
    late ApiStudentRepository apiRepo;

    setUp(() {
      mockRepo = MockStudentRepository();
      apiRepo = ApiStudentRepository(
        remote: StudentRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement StudentRepository', () {
      expect(mockRepo, isA<StudentRepository>());
      expect(apiRepo, isA<StudentRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        StudentDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );
      expect(mapped.studentName, mockData.studentName);
      expect(mapped.todaySchedule.length, mockData.todaySchedule.length);
    });

    test('getAttendance DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAttendance(
        query: kQuery,
        month: DateTime(2026, 6, 1),
      );
      final mapped = _mapper.toAttendance(
        StudentAttendanceResponseDto.fromJson(
          _fixtures.attendanceEnvelope(mockData),
        ),
      );
      expect(mapped.kpi.attendancePercent, mockData.kpi.attendancePercent);
    });

    test('getHomeworkItems DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getHomeworkItems(query: kQuery);
      final mapped = _mapper.toHomeworkItems(
        StudentHomeworkResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final item in mockData) _fixtures.homeworkItem(item),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getExams DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getExams(query: kQuery);
      final mapped = _mapper.toExams(
        StudentExamsResponseDto.fromJson(_fixtures.examsEnvelope(mockData)),
      );
      expect(mapped.upcomingExams.length, mockData.upcomingExams.length);
    });

    test('getTimetable DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getTimetable(query: kQuery);
      final mapped = _mapper.toTimetable(
        StudentTimetableResponseDto.fromJson(
          _fixtures.timetableEnvelope(mockData),
        ),
      );
      expect(mapped.days.length, mockData.days.length);
    });

    test('getNotices DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getNotices(query: kQuery);
      final mapped = _mapper.toNotices(
        StudentNoticesResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final notice in mockData) _fixtures.noticeItem(notice),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getProfile DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getProfile(query: kQuery);
      final mapped = _mapper.toProfile(
        StudentProfileResponseDto.fromJson(
          _fixtures.profileEnvelope(mockData),
        ),
      );
      expect(mapped.studentName, mockData.studentName);
      expect(mapped.parentContacts.length, mockData.parentContacts.length);
    });
  });
}
