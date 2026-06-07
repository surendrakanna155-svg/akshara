import 'package:akshara_erp/core/repositories/api/control_center/api_control_center_repository.dart';
import 'package:akshara_erp/core/repositories/api/control_center/dto/control_center_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/control_center/mapper/control_center_mapper.dart';
import 'package:akshara_erp/core/repositories/api/control_center/remote/control_center_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/control_center_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_control_center_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'control_center_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = ControlCenterFixtureBuilder();
const _mapper = ControlCenterMapper();

void main() {
  group('Control Center repository contract', () {
    late MockControlCenterRepository mockRepo;
    late ApiControlCenterRepository apiRepo;

    setUp(() {
      mockRepo = MockControlCenterRepository();
      apiRepo = ApiControlCenterRepository(
        remote: ControlCenterRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement ControlCenterRepository', () {
      expect(mockRepo, isA<ControlCenterRepository>());
      expect(apiRepo, isA<ControlCenterRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        ControlCenterDashboardDto.fromJson(
          _fixtures.dashboardEnvelope(mockData),
        ),
      );
      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
    });

    test('getSchools DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSchools(query: kQuery);
      final mapped = _mapper.toSchools(
        PlatformSchoolsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final school in mockData) _fixtures.schoolItem(school),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
      expect(mapped.first.name, mockData.first.name);
    });

    test('getSubscriptions DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSubscriptions(query: kQuery);
      final mapped = _mapper.toSubscriptions(
        ControlCenterSubscriptionsResponseDto.fromJson(
          _fixtures.subscriptionsEnvelope(mockData),
        ),
      );
      expect(mapped.plans.length, mockData.plans.length);
    });

    test('getBilling DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getBilling(query: kQuery);
      final mapped = _mapper.toBilling(
        ControlCenterBillingResponseDto.fromJson(
          _fixtures.billingEnvelope(mockData),
        ),
      );
      expect(mapped.invoices.length, mockData.invoices.length);
    });

    test('getCrmPipeline DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getCrmPipeline(query: kQuery);
      final mapped = _mapper.toCrmPipeline(
        ControlCenterCrmResponseDto.fromJson(_fixtures.crmEnvelope(mockData)),
      );
      expect(mapped.deals.length, mockData.deals.length);
    });

    test('getSupportTickets DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSupportTickets(query: kQuery);
      final mapped = _mapper.toSupportTickets(
        SupportTicketsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final ticket in mockData) _fixtures.supportTicketItem(ticket),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getCustomerSuccess DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getCustomerSuccess(query: kQuery);
      final mapped = _mapper.toCustomerSuccess(
        ControlCenterSuccessResponseDto.fromJson(
          _fixtures.customerSuccessEnvelope(mockData),
        ),
      );
      expect(mapped.schools.length, mockData.schools.length);
    });

    test('getWhiteLabelConfigs DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getWhiteLabelConfigs(query: kQuery);
      final mapped = _mapper.toWhiteLabelConfigs(
        WhiteLabelConfigsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final config in mockData) _fixtures.whiteLabelItem(config),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getAnalytics DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAnalytics(query: kQuery);
      final mapped = _mapper.toAnalytics(
        ControlCenterAnalyticsResponseDto.fromJson(
          _fixtures.analyticsEnvelope(mockData),
        ),
      );
      expect(mapped.moduleUsage.length, mockData.moduleUsage.length);
    });

    test('getMonitoring DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getMonitoring(query: kQuery);
      final mapped = _mapper.toMonitoring(
        ControlCenterMonitoringResponseDto.fromJson(
          _fixtures.monitoringEnvelope(mockData),
        ),
      );
      expect(mapped.services.length, mockData.services.length);
    });

    test('getRoles DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getRoles(query: kQuery);
      final mapped = _mapper.toRoles(
        ControlCenterRolesResponseDto.fromJson(
          _fixtures.rolesEnvelope(mockData),
        ),
      );
      expect(mapped.roles.length, mockData.roles.length);
    });

    test('getSettings DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSettings(query: kQuery);
      final mapped = _mapper.toSettings(
        ControlCenterSettingsResponseDto.fromJson(
          _fixtures.settingsEnvelope(mockData),
        ),
      );
      expect(mapped.sections.length, mockData.sections.length);
    });
  });
}
