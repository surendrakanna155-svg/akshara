import 'package:akshara_erp/core/repositories/api/finance/api_finance_repository.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_collections_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_dashboard_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_defaulters_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_discounts_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_fee_structures_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_refunds_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_reports_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_settings_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_student_accounts_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/mapper/finance_mapper.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';
import 'finance_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = FinanceFixtureBuilder();

void main() {
  group('Finance repository contract', () {
    late MockFinanceRepository mockRepo;
    late ApiFinanceRepository apiRepo;

    setUp(() {
      mockRepo = MockFinanceRepository();
      apiRepo = ApiFinanceRepository(
        remote: FinanceRemoteDataSource(Dio()),
        mapper: const FinanceMapper(),
      );
    });

    test('mock and api implement FinanceRepository', () {
      expect(mockRepo, isA<FinanceRepository>());
      expect(apiRepo, isA<FinanceRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = const FinanceMapper().toDashboard(
        FinanceDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );

      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.outstandingAmount, mockData.outstandingAmount);
      expect(mapped.collectionTrend.length, mockData.collectionTrend.length);
      expect(mapped.recentPayments.length, mockData.recentPayments.length);
    });

    test('getCollections DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getCollections(query: kQuery);
      final mapped = const FinanceMapper().toCollections(
        FinanceCollectionsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final payment in mockData) _fixtures.collectionItem(payment),
          ]),
        ),
      );

      expect(mapped.length, mockData.length);
      expect(mapped.first.receiptNumber, mockData.first.receiptNumber);
    });

    test('getDailySummary DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDailySummary(query: kQuery);
      final mapped = const FinanceMapper().toDailySummary(
        DailyCollectionSummaryDto.fromJson(
          _fixtures.dailySummaryEnvelope(mockData),
        ),
      );

      expect(mapped.totalCollected, mockData.totalCollected);
      expect(mapped.transactionCount, mockData.transactionCount);
    });

    test('getFeeStructures DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getFeeStructures(
        query: kQuery,
        academicYear: '2026-27',
      );
      final mapped = const FinanceMapper().toFeeStructures(
        FinanceFeeStructuresResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final structure in mockData)
              _fixtures.feeStructureItem(structure),
          ]),
        ),
      );

      expect(mapped.length, mockData.length);
      expect(mapped.first.name, mockData.first.name);
    });

    test('getAcademicYears DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAcademicYears(query: kQuery);
      final mapped = const FinanceMapper().toAcademicYears(
        FinanceAcademicYearsResponseDto.fromJson(
          _fixtures.academicYearsEnvelope(mockData),
        ),
      );

      expect(mapped, mockData);
    });

    test('getStudentAccounts DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getStudentAccounts(query: kQuery);
      final mapped = const FinanceMapper().toStudentAccounts(
        StudentFeeAccountsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final account in mockData)
              _fixtures.studentAccountItem(account),
          ]),
        ),
      );

      expect(mapped.length, mockData.length);
      expect(mapped.first.admissionNumber, mockData.first.admissionNumber);
    });

    test('getInstallmentPlans DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getInstallmentPlans(query: kQuery);
      final mapped = const FinanceMapper().toInstallmentPlans(
        InstallmentPlansResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final plan in mockData) _fixtures.installmentPlanItem(plan),
          ]),
        ),
      );

      expect(mapped.length, mockData.length);
      expect(mapped.first.label, mockData.first.label);
    });

    test('getCollectionDetail DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getCollectionDetail(
        query: kQuery,
        collectionId: 'col_1',
      );
      expect(mockData, isNotNull);
      final mapped = const FinanceMapper().toCollectionDetail(
        CollectionDetailDto.fromJson(
          _fixtures.collectionDetailEnvelope(mockData!),
        ),
      );

      expect(mapped?.payment.id, mockData.payment.id);
      expect(mapped?.summaryKpis.length, mockData.summaryKpis.length);
    });

    test('getDefaultersDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDefaultersDashboard(query: kQuery);
      final mapped = const FinanceMapper().toDefaultersDashboard(
        DefaultersDashboardDto.fromJson(
          _fixtures.defaultersEnvelope(mockData),
        ),
      );

      expect(mapped.defaulters.length, mockData.defaulters.length);
      expect(mapped.agingBuckets.length, mockData.agingBuckets.length);
    });

    test('getRefundRequests DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getRefundRequests(query: kQuery);
      final mapped = const FinanceMapper().toRefundRequests(
        RefundRequestsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final refund in mockData) _fixtures.refundItem(refund),
          ]),
        ),
      );

      expect(mapped.length, mockData.length);
      expect(mapped.first.status, mockData.first.status);
    });

    test('getDiscountsDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDiscountsDashboard(query: kQuery);
      final mapped = const FinanceMapper().toDiscountsDashboard(
        DiscountsDashboardDto.fromJson(
          _fixtures.discountsEnvelope(mockData),
        ),
      );

      expect(mapped.scholarships.length, mockData.scholarships.length);
      expect(mapped.assignments.length, mockData.assignments.length);
    });

    test('getReportsData DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getReportsData(query: kQuery);
      final mapped = const FinanceMapper().toReports(
        FinanceReportsDto.fromJson(_fixtures.reportsEnvelope(mockData)),
      );

      expect(mapped.catalog.length, mockData.catalog.length);
      expect(mapped.collectionTrend.length, mockData.collectionTrend.length);
    });

    test('getSettings DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSettings(query: kQuery);
      final mapped = const FinanceMapper().toSettings(
        FinanceSettingsDto.fromJson(_fixtures.settingsEnvelope(mockData)),
      );

      expect(mapped.sections.length, mockData.sections.length);
      expect(mapped.academicYear, mockData.academicYear);
    });

    test('mock repository exposes all FinanceRepository methods', () async {
      expect(await mockRepo.getDashboard(query: kQuery), isNotNull);
      expect(await mockRepo.getCollections(query: kQuery), isNotEmpty);
      expect(await mockRepo.getDailySummary(query: kQuery), isNotNull);
      expect(
        await mockRepo.getFeeStructures(
          query: kQuery,
          academicYear: '2026-27',
        ),
        isNotEmpty,
      );
      expect(await mockRepo.getAcademicYears(query: kQuery), isNotEmpty);
      expect(await mockRepo.getStudentAccounts(query: kQuery), isNotEmpty);
      expect(await mockRepo.getInstallmentPlans(query: kQuery), isNotEmpty);
      expect(
        await mockRepo.getCollectionDetail(
          query: kQuery,
          collectionId: 'col_1',
        ),
        isNotNull,
      );
      expect(await mockRepo.getDefaultersDashboard(query: kQuery), isNotNull);
      expect(await mockRepo.getRefundRequests(query: kQuery), isNotEmpty);
      expect(await mockRepo.getDiscountsDashboard(query: kQuery), isNotNull);
      expect(await mockRepo.getReportsData(query: kQuery), isNotNull);
      expect(await mockRepo.getSettings(query: kQuery), isNotNull);
    });

    test('ApiFinanceRepository returns mock-equivalent via fake Dio', () async {
      final mockDashboard = await mockRepo.getDashboard(query: kQuery);
      final mockCollections = await mockRepo.getCollections(query: kQuery);

      final dio = createFakeDio((options) {
        if (options.path.endsWith('/dashboard')) {
          return _fixtures.dashboardEnvelope(mockDashboard);
        }
        if (options.path.endsWith('/collections')) {
          return _fixtures.listEnvelope([
            for (final payment in mockCollections)
              _fixtures.collectionItem(payment),
          ]);
        }
        return {'data': {}};
      });

      final api = ApiFinanceRepository(
        remote: FinanceRemoteDataSource(dio),
      );

      final dashboard = await api.getDashboard(query: kQuery);
      final collections = await api.getCollections(query: kQuery);

      expect(dashboard.kpis.length, mockDashboard.kpis.length);
      expect(collections.length, mockCollections.length);
      expect(collections.first.id, mockCollections.first.id);
    });
  });
}
