import 'package:akshara_erp/core/repositories/api/management/api_management_repository.dart';
import 'package:akshara_erp/core/repositories/api/management/dto/management_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/management/mapper/management_mapper.dart';
import 'package:akshara_erp/core/repositories/api/management/remote/management_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/management_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_management_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/management/management_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'management_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = ManagementFixtureBuilder();
const _mapper = ManagementMapper();

void main() {
  group('Management repository contract', () {
    late MockManagementRepository mockRepo;
    late ApiManagementRepository apiRepo;

    setUp(() {
      mockRepo = MockManagementRepository();
      apiRepo = ApiManagementRepository(
        remote: ManagementRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement ManagementRepository', () {
      expect(mockRepo, isA<ManagementRepository>());
      expect(apiRepo, isA<ManagementRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        ManagementDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );
      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
    });

    test('getAnalytics DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAnalytics(query: kQuery);
      final mapped = _mapper.toAnalytics(
        ManagementAnalyticsResponseDto.fromJson(
          _fixtures.analyticsEnvelope(mockData),
        ),
      );
      expect(mapped.classSummary.length, mockData.classSummary.length);
    });

    test('getAdmissionsFunnel DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAdmissionsFunnel(query: kQuery);
      final mapped = _mapper.toAdmissionsFunnel(
        ManagementAdmissionsFunnelResponseDto.fromJson(
          _fixtures.admissionsFunnelEnvelope(mockData),
        ),
      );
      expect(mapped.funnelStages.length, mockData.funnelStages.length);
    });

    test('getFinancialHealth DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getFinancialHealth(query: kQuery);
      final mapped = _mapper.toFinancialHealth(
        ManagementFinancialHealthResponseDto.fromJson(
          _fixtures.financialHealthEnvelope(mockData),
        ),
      );
      expect(mapped.drillLinks.length, mockData.drillLinks.length);
    });

    test('getAcademicHealth DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAcademicHealth(query: kQuery);
      final mapped = _mapper.toAcademicHealth(
        ManagementAcademicHealthResponseDto.fromJson(
          _fixtures.academicHealthEnvelope(mockData),
        ),
      );
      expect(
          mapped.subjectPerformance.length, mockData.subjectPerformance.length);
    });

    test('getSchoolPerformance DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSchoolPerformance(query: kQuery);
      final mapped = _mapper.toSchoolPerformance(
        ManagementPerformanceResponseDto.fromJson(
          _fixtures.schoolPerformanceEnvelope(mockData),
        ),
      );
      expect(mapped.classPerformance.length, mockData.classPerformance.length);
    });

    test('getTasksAndApprovals DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getTasksAndApprovals(query: kQuery);
      final mapped = _mapper.toTasksAndApprovals(
        ManagementTasksResponseDto.fromJson(_fixtures.tasksEnvelope(mockData)),
      );
      expect(mapped.approvals.length, mockData.approvals.length);
    });

    test('getSettings DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSettings(query: kQuery);
      final mapped = _mapper.toSettings(
        ManagementSettingsResponseDto.fromJson(
          _fixtures.settingsEnvelope(mockData),
        ),
      );
      expect(mapped.sections.length, mockData.sections.length);
    });

    test('updateSettings persists in mock repository', () async {
      final updated = await mockRepo.updateSettings(
        query: kQuery,
        request: const UpdateManagementSettingsRequest(
          updates: [
            ManagementSettingUpdate(
              sectionId: 'school',
              itemId: 'name',
              value: 'NIKSHA Updated School',
            ),
          ],
        ),
      );
      final updatedName = updated.sections
          .firstWhere((section) => section.id == 'school')
          .items
          .firstWhere((item) => item.id == 'name')
          .value;
      expect(updatedName, 'NIKSHA Updated School');
    });
  });
}
