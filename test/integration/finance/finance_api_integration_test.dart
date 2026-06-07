import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/repositories/api/finance/api_finance_repository.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/finance/collections/finance_collections_provider.dart';
import 'package:akshara_erp/features/finance/dashboard/finance_dashboard_provider.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/finance_mutations_provider.dart';
import 'package:akshara_erp/features/finance/finance_requests.dart';
import 'package:akshara_erp/features/finance/student_accounts/finance_student_accounts_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/finance/finance_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = FinanceFixtureBuilder();

void main() {
  group('Finance API integration', () {
    late MockFinanceRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUpAll(() async {
      await initProviderTestPrefs();
    });

    setUp(() async {
      mockRepo = MockFinanceRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final collections = await mockRepo.getCollections(query: kQuery);
      final dailySummary = await mockRepo.getDailySummary(query: kQuery);
      final feeStructures = await mockRepo.getFeeStructures(
        query: kQuery,
        academicYear: '2026-27',
      );
      final academicYears = await mockRepo.getAcademicYears(query: kQuery);
      final studentAccounts = await mockRepo.getStudentAccounts(query: kQuery);
      final installmentPlans =
          await mockRepo.getInstallmentPlans(query: kQuery);
      final collectionDetail = await mockRepo.getCollectionDetail(
        query: kQuery,
        collectionId: 'col_1',
      );
      final defaulters = await mockRepo.getDefaultersDashboard(query: kQuery);
      final refunds = await mockRepo.getRefundRequests(query: kQuery);
      final discounts = await mockRepo.getDiscountsDashboard(query: kQuery);
      final reports = await mockRepo.getReportsData(query: kQuery);
      final settings = await mockRepo.getSettings(query: kQuery);

      responseForPath = (path) => switch (path) {
            FinanceApiPaths.dashboard =>
              _fixtures.dashboardEnvelope(dashboard),
            FinanceApiPaths.collections => _fixtures.listEnvelope([
                for (final payment in collections)
                  _fixtures.collectionItem(payment),
              ]),
            FinanceApiPaths.dailySummary =>
              _fixtures.dailySummaryEnvelope(dailySummary),
            FinanceApiPaths.feeStructures => _fixtures.listEnvelope([
                for (final structure in feeStructures)
                  _fixtures.feeStructureItem(structure),
              ]),
            FinanceApiPaths.academicYears =>
              _fixtures.academicYearsEnvelope(academicYears),
            FinanceApiPaths.studentAccounts => _fixtures.listEnvelope([
                for (final account in studentAccounts)
                  _fixtures.studentAccountItem(account),
              ]),
            FinanceApiPaths.feeAssignment => _fixtures.listEnvelope([
                for (final plan in installmentPlans)
                  _fixtures.installmentPlanItem(plan),
              ]),
            '/finance/collections/col_1' => collectionDetail == null
                ? {'data': {}}
                : _fixtures.collectionDetailEnvelope(collectionDetail),
            FinanceApiPaths.defaulters =>
              _fixtures.defaultersEnvelope(defaulters),
            FinanceApiPaths.refunds => _fixtures.listEnvelope([
                for (final refund in refunds) _fixtures.refundItem(refund),
              ]),
            FinanceApiPaths.discounts =>
              _fixtures.discountsEnvelope(discounts),
            FinanceApiPaths.reports => _fixtures.reportsEnvelope(reports),
            FinanceApiPaths.settings => _fixtures.settingsEnvelope(settings),
            _ => {'data': {}},
          };
    });

    test('remote datasource fetches all finance endpoints', () async {
      final dio = createFakeDio(
        (options) => responseForPath(options.path),
      );
      final remote = FinanceRemoteDataSource(dio);

      final dashboard = await remote.fetchDashboard(query: kQuery);
      expect(dashboard.raw['kpis'], isNotNull);

      final collections = await remote.fetchCollections(query: kQuery);
      expect(collections.items, isNotEmpty);

      final dailySummary = await remote.fetchDailySummary(query: kQuery);
      expect(dailySummary.raw['totalCollected'], isNotNull);

      final feeStructures = await remote.fetchFeeStructures(
        query: kQuery,
        academicYear: '2026-27',
      );
      expect(feeStructures.items, isNotEmpty);

      final academicYears = await remote.fetchAcademicYears(query: kQuery);
      expect(academicYears.items, isNotEmpty);

      final studentAccounts = await remote.fetchStudentAccounts(query: kQuery);
      expect(studentAccounts.items.length, 4);

      final installmentPlans = await remote.fetchFeeAssignment(query: kQuery);
      expect(installmentPlans.items.length, 4);

      final collectionDetail = await remote.fetchCollectionDetail(
        query: kQuery,
        collectionId: 'col_1',
      );
      expect(collectionDetail.raw['payment'], isNotNull);

      final defaulters = await remote.fetchDefaultersDashboard(query: kQuery);
      expect(defaulters.raw['defaulters'], isNotNull);

      final refunds = await remote.fetchRefundRequests(query: kQuery);
      expect(refunds.items.length, 3);

      final discounts = await remote.fetchDiscountsDashboard(query: kQuery);
      expect(discounts.raw['scholarships'], isNotNull);

      final reports = await remote.fetchReports(query: kQuery);
      expect(reports.raw['catalog'], isNotNull);

      final settings = await remote.fetchSettings(query: kQuery);
      expect(settings.raw['sections'], isNotNull);
    });

    test('provider to repository to remote returns domain models', () async {
      final dio = createFakeDio(
        (options) => responseForPath(options.path),
      );
      final apiRepo = ApiFinanceRepository(
        remote: FinanceRemoteDataSource(dio),
      );

      final mockCollections = await mockRepo.getCollections(query: kQuery);
      final apiCollections = await apiRepo.getCollections(query: kQuery);

      expect(apiCollections.length, mockCollections.length);
      expect(
        apiCollections.map((p) => p.id).toList(),
        mockCollections.map((p) => p.id).toList(),
      );
    });

    test('finance dashboard provider loads via API repository', () async {
      final dio = createFakeDio(
        (options) => responseForPath(options.path),
      );

      final container = createProviderTestContainer(
        apiFinanceDio: dio,
        financeApiEnabled: true,
      );
      addTearDown(container.dispose);

      final dashboard = await container.read(
        financeDashboardFutureProvider.future,
      );

      expect(dashboard.kpis, hasLength(6));
      expect(dashboard.collectionTrend, hasLength(6));
    });

    test('finance collections provider loads via API repository', () async {
      final dio = createFakeDio(
        (options) => responseForPath(options.path),
      );

      final container = createProviderTestContainer(
        apiFinanceDio: dio,
        financeApiEnabled: true,
      );
      addTearDown(container.dispose);

      final collections = await container.read(
        financeCollectionsFutureProvider.future,
      );

      expect(collections, isNotEmpty);
      expect(collections.first.receiptNumber, isNotEmpty);
    });

    test('remote datasource posts fee structure create', () async {
      final mockStructures = await mockRepo.getFeeStructures(
        query: kQuery,
        academicYear: '2026-27',
      );
      const created = FinanceFeeStructure(
        id: 'fee_new',
        name: 'API Structure',
        academicYear: '2026-27',
        totalAnnual: '₹2,00,000',
        classRange: '1 – 8',
        status: FeeStructureStatus.active,
        installmentOptions: [3],
        categories: [
          FeeCategoryLine(
            category: FeeStructureCategory.tuition,
            label: 'Tuition',
            amount: '₹2,00,000',
          ),
        ],
      );

      final dio = createFakeDio((options) {
        if (options.method == 'POST' &&
            options.path == FinanceApiPaths.feeStructures) {
          return _fixtures.envelope(_fixtures.feeStructureItem(created));
        }
        return responseForPath(options.path);
      });
      final remote = FinanceRemoteDataSource(dio);

      final result = await remote.createFeeStructure(
        query: kQuery,
        request: const CreateFeeStructureRequest(
          name: 'API Structure',
          academicYear: '2026-27',
          totalAnnual: '₹2,00,000',
          classRange: '1 – 8',
          categories: [
            FeeCategoryLine(
              category: FeeStructureCategory.tuition,
              label: 'Tuition',
              amount: '₹2,00,000',
            ),
          ],
        ),
      );

      expect(result.id, 'fee_new');
      expect(mockStructures, isNotEmpty);
    });

    test('approve refund mutation refreshes refunds provider', () async {
      final refunds = await mockRepo.getRefundRequests(query: kQuery);
      final pending = refunds.firstWhere(
        (refund) => refund.status == RefundStatus.pending,
      );
      final approved = RefundRequest(
        id: pending.id,
        studentName: pending.studentName,
        admissionNumber: pending.admissionNumber,
        classLabel: pending.classLabel,
        amount: pending.amount,
        reason: pending.reason,
        requestedAt: pending.requestedAt,
        status: RefundStatus.approved,
        approver: pending.approver,
        feeAccountId: pending.feeAccountId,
        originalReceipt: pending.originalReceipt,
      );

      final dio = createFakeDio((options) {
        if (options.method == 'PATCH' &&
            options.path == FinanceApiPaths.refundApprove(pending.id)) {
          return _fixtures.envelope(_fixtures.refundItem(approved));
        }
        return responseForPath(options.path);
      });

      final container = createProviderTestContainer(
        apiFinanceDio: dio,
        financeApiEnabled: true,
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(approveRefundProvider.notifier)
          .execute(refundId: pending.id);

      expect(result?.status, RefundStatus.approved);
      expect(result?.id, pending.id);
    });

    test('finance student accounts provider loads via API repository', () async {
      final dio = createFakeDio(
        (options) => responseForPath(options.path),
      );

      final container = createProviderTestContainer(
        apiFinanceDio: dio,
        financeApiEnabled: true,
      );
      addTearDown(container.dispose);

      final accounts = await container.read(
        financeStudentAccountsFutureProvider.future,
      );

      expect(accounts, hasLength(4));
    });
  });
}
