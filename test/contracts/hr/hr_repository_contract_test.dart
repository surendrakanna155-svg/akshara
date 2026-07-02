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

    // --- HR reporting / export reads (HR-1/2/4/5/6/7) -----------------------

    test('getSalaryRegister DTO mapping matches mock output (HR-1)', () async {
      final mockData =
          await mockRepo.getSalaryRegister(query: kQuery, runId: 'pay_run_1');
      final mapped = _mapper.toSalaryRegister(
        HrSalaryRegisterDto.fromJson(_fixtures.salaryRegisterEnvelope(mockData)),
      );
      expect(mapped.rows.length, mockData.rows.length);
      expect(mapped.totals.netPay, mockData.totals.netPay);
      // Totals equal the column sum of the mapped rows.
      final sum = mapped.rows.fold<num>(0, (a, r) => a + r.netPay);
      expect(mapped.totals.netPay, sum);
    });

    test('getPayslips DTO mapping matches mock output (HR-2)', () async {
      final mockData =
          await mockRepo.getPayslips(query: kQuery, runId: 'pay_run_1');
      final mapped = _mapper.toPayslips(
        HrPayslipsDto.fromJson(_fixtures.payslipsEnvelope(mockData)),
      );
      expect(mapped.payslips.length, mockData.payslips.length);
      if (mapped.payslips.isNotEmpty) {
        final p = mapped.payslips.first;
        expect(p.grossEarnings, p.earnings.fold<num>(0, (a, l) => a + l.amount));
      }
    });

    test('getAttendanceMuster DTO mapping matches mock output (HR-6)', () async {
      final mockData =
          await mockRepo.getAttendanceMuster(query: kQuery, month: '2026-06');
      final mapped = _mapper.toAttendanceMuster(
        HrAttendanceMusterDto.fromJson(_fixtures.musterEnvelope(mockData)),
      );
      expect(mapped.month, '2026-06');
      expect(mapped.daysInMonth, mockData.daysInMonth);
      expect(mapped.rows.length, mockData.rows.length);
      if (mapped.rows.isNotEmpty) {
        expect(mapped.rows.first.dailyStatus.length, mapped.daysInMonth);
      }
    });

    test('getLeaveBalances DTO mapping matches mock output (HR-4)', () async {
      final mockData = await mockRepo.getLeaveBalances(query: kQuery);
      final mapped = _mapper.toLeaveBalances(
        HrLeaveBalancesDto.fromJson(_fixtures.leaveBalancesEnvelope(mockData)),
      );
      expect(mapped.leaveTypes, mockData.leaveTypes);
      expect(mapped.rows.length, mockData.rows.length);
    });

    test('getHeadcount DTO mapping matches mock output (HR-5)', () async {
      final mockData = await mockRepo.getHeadcount(query: kQuery);
      final mapped = _mapper.toHeadcount(
        HrHeadcountDto.fromJson(_fixtures.headcountEnvelope(mockData)),
      );
      expect(mapped.total, mockData.total);
      expect(mapped.rows.length, mockData.rows.length);
      // Grouped counts sum to the total.
      expect(mapped.rows.fold<int>(0, (a, r) => a + r.count), mapped.total);
    });

    test('getEmployeeDirectory DTO mapping matches mock output (HR-7)', () async {
      final mockData = await mockRepo.getEmployeeDirectory(query: kQuery);
      final mapped = _mapper.toEmployeeDirectory(
        HrEmployeeDirectoryDto.fromJson(_fixtures.directoryEnvelope(mockData)),
      );
      expect(mapped.rows.length, mockData.rows.length);
      if (mapped.rows.isNotEmpty) {
        expect(mapped.rows.first.code, mockData.rows.first.code);
      }
    });
  });
}
