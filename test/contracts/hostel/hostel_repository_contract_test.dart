import 'package:akshara_erp/core/repositories/api/hostel/api_hostel_repository.dart';
import 'package:akshara_erp/core/repositories/api/hostel/dto/hostel_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/hostel/mapper/hostel_mapper.dart';
import 'package:akshara_erp/core/repositories/api/hostel/remote/hostel_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/hostel_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_hostel_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hostel_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = HostelFixtureBuilder();
const _mapper = HostelMapper();

void main() {
  group('Hostel repository contract', () {
    late MockHostelRepository mockRepo;
    late ApiHostelRepository apiRepo;

    setUp(() {
      mockRepo = MockHostelRepository();
      apiRepo = ApiHostelRepository(
        remote: HostelRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement HostelRepository', () {
      expect(mockRepo, isA<HostelRepository>());
      expect(apiRepo, isA<HostelRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        HostelDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );
      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
    });

    test('getStudents DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getStudents(query: kQuery);
      final mapped = _mapper.toStudents(
        HostelStudentsResponseDto.fromJson(_fixtures.studentsEnvelope(mockData)),
      );
      expect(mapped.length, mockData.length);
      expect(mapped.first.admissionNumber, mockData.first.admissionNumber);
    });

    test('getRooms DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getRooms(query: kQuery);
      final mapped = _mapper.toRooms(
        HostelRoomsResponseDto.fromJson(_fixtures.roomsEnvelope(mockData)),
      );
      expect(mapped.length, mockData.length);
    });

    test('getAttendanceRecords DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAttendanceRecords(query: kQuery);
      final mapped = _mapper.toAttendanceRecords(
        HostelAttendanceResponseDto.fromJson(
          _fixtures.attendanceEnvelope(mockData),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getLeaveRequests DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getLeaveRequests(query: kQuery);
      final mapped = _mapper.toLeaveRequests(
        HostelLeaveResponseDto.fromJson(_fixtures.leaveEnvelope(mockData)),
      );
      expect(mapped.length, mockData.length);
    });

    test('getMessData DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getMessData(query: kQuery);
      final mapped = _mapper.toMessData(
        HostelMessResponseDto.fromJson(_fixtures.messEnvelope(mockData)),
      );
      expect(mapped.weeklyMenus.length, mockData.weeklyMenus.length);
    });

    test('getVisitors DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getVisitors(query: kQuery);
      final mapped = _mapper.toVisitors(
        HostelVisitorsResponseDto.fromJson(_fixtures.visitorsEnvelope(mockData)),
      );
      expect(mapped.activeVisitors.length, mockData.activeVisitors.length);
    });

    test('getReports DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getReports(query: kQuery);
      final mapped = _mapper.toReports(
        HostelReportsResponseDto.fromJson(_fixtures.reportsEnvelope(mockData)),
      );
      expect(mapped.catalog.length, mockData.catalog.length);
    });

    test('getOccupancyMetrics DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getOccupancyMetrics(query: kQuery);
      final mapped = _mapper.toOccupancyMetrics(
        HostelOccupancyMetricsDto.fromJson(
          _fixtures.occupancyMetricsEnvelope(mockData),
        ),
      );
      expect(mapped.totalBeds, mockData.totalBeds);
    });
  });
}
