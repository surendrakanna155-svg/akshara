import 'package:akshara_erp/core/repositories/api/hr/api_hr_repository.dart';
import 'package:akshara_erp/core/repositories/api/hr/dto/hr_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/hr/mapper/hr_mapper.dart';
import 'package:akshara_erp/core/repositories/api/hr/remote/hr_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/hr_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_hr_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hr_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = HrFixtureBuilder();
const _mapper = HrMapper();

void main() {
  group('HR repository contract', () {
    late MockHrRepository mockRepo;
    late ApiHrRepository apiRepo;

    setUp(() {
      mockRepo = MockHrRepository();
      apiRepo = ApiHrRepository(
        remote: HrRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement HrRepository', () {
      expect(mockRepo, isA<HrRepository>());
      expect(apiRepo, isA<HrRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        HrDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );
      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
    });

    test('getEmployees DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getEmployees(query: kQuery);
      final mapped = _mapper.toEmployees(
        HrEmployeesResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final employee in mockData.items) _fixtures.employeeItem(employee),
          ]),
        ),
      );
      expect(mapped.length, mockData.items.length);
      expect(mapped.first.employeeCode, mockData.items.first.employeeCode);
    });

    test('getEmployeeDetail DTO mapping matches mock output', () async {
      const employeeId = 'HR-EMP-101';
      final mockDetail = await mockRepo.getEmployeeDetail(
        query: kQuery,
        employeeId: employeeId,
      );
      expect(mockDetail, isNotNull);
      final mapped = _mapper.toEmployeeDetail(
        HrEmployeeDetailDto.fromJson(
          _fixtures.employeeDetailEnvelope(mockDetail!),
        ),
      );
      expect(mapped?.employee.id, mockDetail.employee.id);
      expect(mapped?.documents.length, mockDetail.documents.length);
    });

    test('getAttendance DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAttendance(query: kQuery);
      final mapped = _mapper.toAttendance(
        HrAttendanceResponseDto.fromJson(
          _fixtures.attendanceEnvelope(mockData),
        ),
      );
      expect(mapped.records.length, mockData.records.length);
    });

    test('getLeave DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getLeave(query: kQuery);
      final mapped = _mapper.toLeave(
        HrLeaveResponseDto.fromJson(_fixtures.leaveEnvelope(mockData)),
      );
      expect(mapped.requests.length, mockData.requests.length);
    });

    test('getPayroll DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getPayroll(query: kQuery);
      final mapped = _mapper.toPayroll(
        HrPayrollResponseDto.fromJson(_fixtures.payrollEnvelope(mockData)),
      );
      expect(mapped.runs.length, mockData.runs.length);
    });

    test('getRecruitment DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getRecruitment(query: kQuery);
      final mapped = _mapper.toRecruitment(
        HrRecruitmentResponseDto.fromJson(
          _fixtures.recruitmentEnvelope(mockData),
        ),
      );
      expect(mapped.candidates.length, mockData.candidates.length);
    });

    test('getPerformance DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getPerformance(query: kQuery);
      final mapped = _mapper.toPerformance(
        HrPerformanceResponseDto.fromJson(
          _fixtures.performanceEnvelope(mockData),
        ),
      );
      expect(mapped.reviews.length, mockData.reviews.length);
    });

    test('getSettings DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSettings(query: kQuery);
      final mapped = _mapper.toSettings(
        HrSettingsResponseDto.fromJson(_fixtures.settingsEnvelope(mockData)),
      );
      expect(mapped.sections.length, mockData.sections.length);
    });
  });
}
