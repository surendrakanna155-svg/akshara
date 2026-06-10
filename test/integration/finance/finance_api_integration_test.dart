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
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/finance/finance_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = FinanceFixtureBuilder();

void main() {
  group('Finance API integration', () {
    late MockFinanceRepository mockRepo;
    late Map<String, dynamic> Function(String path, String method) responseFor;

    setUpAll(() async {
      await initProviderTestPrefs();
    });

    setUp(() async {
      mockRepo = MockFinanceRepository();
      final dailySummary = await mockRepo.getDailySummary(query: kQuery);
      final feeStructures = await mockRepo.getFeeStructures(
        query: kQuery,
        academicYear: '2026-27',
      );
      final studentAccounts = await mockRepo.getStudentAccounts(query: kQuery);
      final collectionDetail = await mockRepo.getCollectionDetail(
        query: kQuery,
        collectionId: 'col_1',
      );
      final refunds = await mockRepo.getRefundRequests(query: kQuery);
      final invoices = await mockRepo.getInvoices(query: kQuery);
      final collectionCreateResult = await mockRepo.createCollection(
        query: kQuery,
        request: const CreateCollectionRequest(
          invoiceId: 'inv_1',
          amountCollected: '5000',
          paymentMethod: 'upi',
        ),
      );
      final collectionsAfterCreate = await mockRepo.getCollections(query: kQuery);

      responseFor = (path, method) {
        if (path == FinanceApiPaths.dashboard) {
          return _fixtures.apiDashboardEnvelope();
        }
        if (path == FinanceApiPaths.collections && method == 'GET') {
          return _fixtures.listEnvelope([
            for (final payment in collectionsAfterCreate.items)
              _fixtures.collectionItem(payment),
          ]);
        }
        if (path == FinanceApiPaths.collections && method == 'POST') {
          return _fixtures.collectionResultEnvelope(collectionCreateResult);
        }
        if (path == FinanceApiPaths.dailySummary) {
          return _fixtures.dailySummaryEnvelope(dailySummary);
        }
        if (path == FinanceApiPaths.feeStructures) {
          return _fixtures.listEnvelope([
            for (final structure in feeStructures.items)
              _fixtures.feeStructureItem(structure),
          ]);
        }
        if (path == FinanceApiPaths.feeAssignments) {
          return _fixtures.listEnvelope([
            for (var i = 0; i < studentAccounts.items.length; i++)
              {
                'id': 'assignment_$i',
                'studentId': 'student_$i',
                'academicYear': studentAccounts.items[i].feeStructureName.isEmpty
                    ? '2026-27'
                    : '2026-27',
                'assignmentStatus': 'active',
                'feeStructureId': 'fee_$i',
              },
          ]);
        }
        if (path.startsWith('${FinanceApiPaths.studentAccounts}/')) {
          final studentId = path.split('/').last;
          final index = int.tryParse(studentId.split('_').last) ?? 0;
          final account = studentAccounts.items[index];
          return _fixtures.envelope(_fixtures.studentAccountItem(account));
        }
        if (path == '/finance/collections/col_1') {
          return collectionDetail == null
              ? {'data': {}}
              : _fixtures.collectionDetailEnvelope(collectionDetail);
        }
        if (path == FinanceApiPaths.refunds && method == 'GET') {
          return _fixtures.listEnvelope([
            for (final refund in refunds.items) _fixtures.refundItem(refund),
          ]);
        }
        if (path.startsWith('${FinanceApiPaths.refunds}/') &&
            method == 'GET' &&
            !path.endsWith('/approve') &&
            !path.endsWith('/reject')) {
          final refundId = path.split('/').last;
          final refund = refunds.items.firstWhere((item) => item.id == refundId);
          return _fixtures.envelope(_fixtures.refundItem(refund));
        }
        if (path == FinanceApiPaths.invoices && method == 'GET') {
          return _fixtures.listEnvelope([
            for (final invoice in invoices.items) _fixtures.invoiceItem(invoice),
          ]);
        }
        if (path.startsWith('${FinanceApiPaths.invoices}/') &&
            method == 'GET' &&
            !path.endsWith('/issue') &&
            !path.endsWith('/cancel')) {
          final invoiceId = path.split('/').last;
          final invoice = invoices.items.firstWhere((item) => item.id == invoiceId);
          return _fixtures.envelope(_fixtures.invoiceItem(invoice));
        }
        return {'data': {}};
      };
    });

    test('remote datasource fetches aligned finance endpoints', () async {
      final dio = createFakeDio(
        (options) => responseFor(options.path, options.method),
      );
      final remote = FinanceRemoteDataSource(dio);

      final collections = await remote.fetchCollections(query: kQuery);
      expect(collections.items, isNotEmpty);

      final dailySummary = await remote.fetchDailySummary(query: kQuery);
      expect(dailySummary.raw['totalCollected'], isNotNull);

      final feeStructures = await remote.fetchFeeStructures(
        query: kQuery,
        academicYear: '2026-27',
      );
      expect(feeStructures.items, isNotEmpty);

      final assignments = await remote.fetchFeeAssignments(query: kQuery);
      expect(assignments.items, isNotEmpty);

      final account = await remote.fetchStudentAccount(
        query: kQuery,
        studentId: 'student_0',
        academicYear: '2026-27',
      );
      expect(account.raw['studentName'], isNotNull);

      final invoiceList = await remote.fetchInvoices(query: kQuery);
      expect(invoiceList.items, isNotEmpty);
    });

    test('api repository matches mock invoice list', () async {
      final dio = createFakeDio(
        (options) => responseFor(options.path, options.method),
      );
      final apiRepo = ApiFinanceRepository(
        remote: FinanceRemoteDataSource(dio),
      );

      final mockInvoices = await mockRepo.getInvoices(query: kQuery);
      final apiInvoices = await apiRepo.getInvoices(query: kQuery);

      expect(apiInvoices.items.length, mockInvoices.items.length);
      expect(
        apiInvoices.items.first.invoiceNumber,
        mockInvoices.items.first.invoiceNumber,
      );
    });

    test('api repository loads invoice detail', () async {
      final dio = createFakeDio(
        (options) => responseFor(options.path, options.method),
      );
      final apiRepo = ApiFinanceRepository(
        remote: FinanceRemoteDataSource(dio),
      );

      final invoice = await apiRepo.getInvoice(
        query: kQuery,
        invoiceId: 'inv_1',
      );
      expect(invoice?.invoiceStatus, InvoiceStatus.issued);
      expect(invoice?.termLabel, 'Annual');
    });

    test('api repository records collection and updates invoice', () async {
      final dio = createFakeDio(
        (options) => responseFor(options.path, options.method),
      );
      final apiRepo = ApiFinanceRepository(
        remote: FinanceRemoteDataSource(dio),
      );

      final result = await apiRepo.createCollection(
        query: kQuery,
        request: const CreateCollectionRequest(
          invoiceId: 'inv_1',
          amountCollected: '5000',
          paymentMethod: 'upi',
        ),
      );
      expect(result.collectionId, isNotEmpty);
      expect(result.invoice.invoiceStatus, InvoiceStatus.partiallyPaid);
    });

    test('api repository derives academic years from fee structures', () async {
      final dio = createFakeDio(
        (options) => responseFor(options.path, options.method),
      );
      final apiRepo = ApiFinanceRepository(
        remote: FinanceRemoteDataSource(dio),
      );

      final years = await apiRepo.getAcademicYears(query: kQuery);
      expect(years.items, contains('2026-27'));
    });

    test('api repository loads installment plans from client catalog', () async {
      final apiRepo = ApiFinanceRepository(
        remote: FinanceRemoteDataSource(Dio()),
      );
      final plans = await apiRepo.getInstallmentPlans(query: kQuery);
      expect(plans.items, isNotEmpty);
      expect(
        plans.items.any((plan) => plan.type == InstallmentPlanType.annual),
        isTrue,
      );
    });

    test('provider to repository to remote returns domain models', () async {
      final dio = createFakeDio(
        (options) => responseFor(options.path, options.method),
      );
      final apiRepo = ApiFinanceRepository(
        remote: FinanceRemoteDataSource(dio),
      );

      final mockCollections = await mockRepo.getCollections(query: kQuery);
      final apiCollections = await apiRepo.getCollections(query: kQuery);

      expect(apiCollections.items.length, mockCollections.items.length);
    });

    test('finance dashboard provider loads via API in hybrid mode', () async {
      final dio = createFakeDio(
        (options) => responseFor(options.path, options.method),
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
      expect(dashboard.recentPayments, hasLength(1));
      expect(dashboard.outstandingAmount, '₹30K');
    });

    test('finance collections provider loads via API repository', () async {
      final dio = createFakeDio(
        (options) => responseFor(options.path, options.method),
      );

      final container = createProviderTestContainer(
        apiFinanceDio: dio,
        financeApiEnabled: true,
      );
      addTearDown(container.dispose);

      final collections = await container.read(
        financeCollectionsFutureProvider.future,
      );

      expect(collections.items, isNotEmpty);
      expect(collections.items.first.receiptNumber, isNotEmpty);
    });

    test('remote datasource posts fee structure create', () async {
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
        return responseFor(options.path, options.method);
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
    });

    test('approve refund mutation uses POST and processed status', () async {
      final refunds = await mockRepo.getRefundRequests(query: kQuery);
      final pending = refunds.items.firstWhere(
        (refund) => refund.status == RefundStatus.pending,
      );
      final processed = RefundRequest(
        id: pending.id,
        studentName: pending.studentName,
        admissionNumber: pending.admissionNumber,
        classLabel: pending.classLabel,
        amount: pending.amount,
        reason: pending.reason,
        requestedAt: pending.requestedAt,
        status: RefundStatus.processed,
        approver: pending.approver,
        feeAccountId: pending.feeAccountId,
        originalReceipt: pending.originalReceipt,
        collectionId: pending.collectionId,
        invoiceId: pending.invoiceId,
      );

      final dio = createFakeDio((options) {
        if (options.method == 'POST' &&
            options.path == FinanceApiPaths.refundApprove(pending.id)) {
          return _fixtures.envelope(_fixtures.refundItem(processed));
        }
        return responseFor(options.path, options.method);
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

      expect(result?.status, RefundStatus.processed);
      expect(result?.id, pending.id);
    });

    test('reject refund mutation uses POST reject route', () async {
      final refunds = await mockRepo.getRefundRequests(query: kQuery);
      final pending = refunds.items.firstWhere(
        (refund) => refund.status == RefundStatus.pending,
      );
      final rejected = RefundRequest(
        id: pending.id,
        studentName: pending.studentName,
        admissionNumber: pending.admissionNumber,
        classLabel: pending.classLabel,
        amount: pending.amount,
        reason: pending.reason,
        requestedAt: pending.requestedAt,
        status: RefundStatus.rejected,
        approver: pending.approver,
        feeAccountId: pending.feeAccountId,
        originalReceipt: pending.originalReceipt,
        collectionId: pending.collectionId,
        invoiceId: pending.invoiceId,
      );

      final dio = createFakeDio((options) {
        if (options.method == 'POST' &&
            options.path == FinanceApiPaths.refundReject(pending.id)) {
          return _fixtures.envelope(_fixtures.refundItem(rejected));
        }
        return responseFor(options.path, options.method);
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
          .read(rejectRefundProvider.notifier)
          .execute(refundId: pending.id);

      expect(result?.status, RefundStatus.rejected);
      expect(result?.id, pending.id);
    });

    test('getRefund fetches refund detail by id', () async {
      final dio = createFakeDio(
        (options) => responseFor(options.path, options.method),
      );
      final apiRepo = ApiFinanceRepository(
        remote: FinanceRemoteDataSource(dio),
      );

      final mockRefund = await mockRepo.getRefund(
        query: kQuery,
        refundId: 'ref_1',
      );
      final apiRefund = await apiRepo.getRefund(
        query: kQuery,
        refundId: 'ref_1',
      );

      expect(apiRefund?.id, mockRefund?.id);
      expect(apiRefund?.collectionId, mockRefund?.collectionId);
      expect(apiRefund?.invoiceId, mockRefund?.invoiceId);
    });

    test('finance student accounts provider loads via assignment bridge', () async {
      final dio = createFakeDio(
        (options) => responseFor(options.path, options.method),
      );

      final container = createProviderTestContainer(
        apiFinanceDio: dio,
        financeApiEnabled: true,
      );
      addTearDown(container.dispose);

      final accounts = await container.read(
        financeStudentAccountsFutureProvider.future,
      );

      expect(accounts.items, hasLength(4));
      expect(accounts.total, 4);
    });
  });
}
