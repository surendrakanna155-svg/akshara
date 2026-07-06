import 'package:akshara_erp/core/repositories/api/finance/api_finance_repository.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/create_collection_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_collections_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_dashboard_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_defaulters_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_discounts_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_fee_structures_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_invoices_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_d_features_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_refunds_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_reports_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_settings_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_student_accounts_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/offline_payment_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/qr_payment_session_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/finance_recovery_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/mapper/finance_mapper.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/finance_requests.dart';
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

    test('getDashboard API envelope maps to domain KPIs', () {
      final mapped = const FinanceMapper().toDashboard(
        FinanceDashboardDto.fromJson(_fixtures.apiDashboardEnvelope()),
      );

      expect(mapped.kpis, hasLength(6));
      expect(mapped.outstandingAmount, '₹30K');
      expect(mapped.recentPayments.single.studentName, 'Probe Student');
      expect(mapped.collectionTrend, isEmpty);
    });

    test('getCollections DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getCollections(query: kQuery);
      final mapped = const FinanceMapper().toCollections(
        FinanceCollectionsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final payment in mockData.items)
              _fixtures.collectionItem(payment),
          ]),
        ),
      );

      expect(mapped.length, mockData.items.length);
      expect(mapped.first.receiptNumber, mockData.items.first.receiptNumber);
    });

    test('createCollection result maps invoice status transitions', () async {
      final mockResult = await mockRepo.createCollection(
        query: kQuery,
        request: const CreateCollectionRequest(
          invoiceId: 'inv_1',
          amountCollected: '10000',
          paymentMethod: 'cash',
        ),
      );
      final mapped = const FinanceMapper().toCollectionResult(
        FinanceCollectionResultDto.fromJson(
          _fixtures.collectionResultEnvelope(mockResult)['data']
              as Map<String, dynamic>,
        ),
      );
      expect(mapped.invoice.invoiceStatus, InvoiceStatus.partiallyPaid);
      expect(mapped.receipt.receiptNumber, isNotEmpty);
    });

    test('listOfflinePayments DTO mapping matches mock output', () async {
      final mockData = await mockRepo.listOfflinePayments(query: kQuery);
      final mapped = const FinanceMapper().toOfflinePayments(
        OfflinePaymentsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final payment in mockData.items)
              _fixtures.offlinePaymentItem(payment),
          ]),
        ),
      );
      expect(mapped.length, mockData.items.length);
      expect(mapped.first.status, mockData.items.first.status);
    });

    test('record and reconcile offline payment updates status', () async {
      final recorded = await mockRepo.recordOfflinePayment(
        query: kQuery,
        request: const RecordOfflinePaymentRequest(
          invoiceId: 'inv_1',
          studentName: 'Contract Student',
          amount: '5000',
          method: OfflinePaymentMethod.cash,
          referenceNumber: 'CASH-CONTRACT-1',
          recordedAt: '2026-06-12',
        ),
      );
      expect(recorded.status, OfflinePaymentStatus.pendingReconciliation);

      final reconciled = await mockRepo.reconcileOfflinePayment(
        query: kQuery,
        offlinePaymentId: recorded.id,
        request: const ReconcileOfflinePaymentRequest(),
      );
      expect(reconciled.status, OfflinePaymentStatus.reconciled);
      expect(reconciled.collectionId, isNotEmpty);
    });

    test('FIN-R7: bounce a PDC — terminal, money-safe, carries instrument data',
        () async {
      final recorded = await mockRepo.recordOfflinePayment(
        query: kQuery,
        request: const RecordOfflinePaymentRequest(
          invoiceId: 'inv_1',
          studentName: 'PDC Student',
          amount: '5000',
          method: OfflinePaymentMethod.pdc,
          referenceNumber: 'CHQ-77120',
          recordedAt: '2026-06-12',
          instrumentDate: '2026-08-15',
          bankName: 'State Bank',
        ),
      );
      expect(recorded.method, OfflinePaymentMethod.pdc);
      expect(recorded.instrumentDate, '2026-08-15');
      expect(recorded.bankName, 'State Bank');

      final bounced = await mockRepo.bounceOfflinePayment(
        query: kQuery,
        offlinePaymentId: recorded.id,
        request: const BounceOfflinePaymentRequest(reason: 'Insufficient funds'),
      );
      expect(bounced.status, OfflinePaymentStatus.bounced);
      expect(bounced.bouncedReason, 'Insufficient funds');
      // Money-safe: a bounce spawns NO collection — it reverses nothing.
      expect(bounced.collectionId, isNull);

      // A bounced (dishonoured) instrument is terminal — cannot be reconciled.
      await expectLater(
        mockRepo.reconcileOfflinePayment(
          query: kQuery,
          offlinePaymentId: recorded.id,
          request: const ReconcileOfflinePaymentRequest(),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('FIN-R6: setting a collection target computes attainment', () async {
      final before = await mockRepo.getRecoveryDashboard(query: kQuery);
      final collector = before.collectorPerformance.first;
      expect(collector.target, isNull);
      expect(collector.attainmentPct, isNull);

      // Recovered is 95000; a 100000 target → 95% attainment.
      final after = await mockRepo.setCollectionTarget(
        query: kQuery,
        request: SetCollectionTargetRequest(
          collectorUserId: collector.collectorId,
          periodMonth: before.period,
          target: '100000',
        ),
      );
      final updated = after.collectorPerformance
          .firstWhere((c) => c.collectorId == collector.collectorId);
      expect(updated.target, '100000');
      expect(updated.attainmentPct, 95);
    });

    test('qr payment session DTO maps to domain model', () {
      final mapped = const FinanceMapper().toQrPaymentSession(
        QrPaymentSessionDto.fromJson(
          _fixtures.qrPaymentSessionItem(
            QrPaymentSession(
              id: 'qr_1',
              invoiceId: 'inv_1',
              amount: '4500',
              upiPayload: 'upi://pay?pa=school@upi&pn=Akshara&am=4500&tr=qr_1',
              status: QrPaymentSessionStatus.pending,
              expiresAt: DateTime.utc(2026, 6, 15, 9, 0, 0),
            ),
          ),
        ),
      );
      expect(mapped.id, 'qr_1');
      expect(mapped.status, QrPaymentSessionStatus.pending);
      expect(mapped.upiPayload, contains('upi://pay?'));
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
            for (final structure in mockData.items)
              _fixtures.feeStructureItem(structure),
          ]),
        ),
      );

      expect(mapped.length, mockData.items.length);
      expect(mapped.first.name, mockData.items.first.name);
    });

    test('getAcademicYears DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAcademicYears(query: kQuery);
      final mapped = const FinanceMapper().toAcademicYears(
        FinanceAcademicYearsResponseDto.fromJson(
          _fixtures.academicYearsEnvelope(mockData.items),
        ),
      );

      expect(mapped, mockData.items);
    });

    test('getStudentAccounts DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getStudentAccounts(query: kQuery);
      final mapped = const FinanceMapper().toStudentAccounts(
        StudentFeeAccountsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final account in mockData.items)
              _fixtures.studentAccountItem(account),
          ]),
        ),
      );

      expect(mapped.length, mockData.items.length);
      expect(
          mapped.first.admissionNumber, mockData.items.first.admissionNumber);
    });

    test('getInstallmentPlans DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getInstallmentPlans(query: kQuery);
      final mapped = const FinanceMapper().toInstallmentPlans(
        InstallmentPlansResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final plan in mockData.items)
              _fixtures.installmentPlanItem(plan),
          ]),
        ),
      );

      expect(mapped.length, mockData.items.length);
      expect(mapped.first.label, mockData.items.first.label);
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
            for (final refund in mockData.items) _fixtures.refundItem(refund),
          ]),
        ),
      );

      expect(mapped.length, mockData.items.length);
      expect(mapped.first.status, mockData.items.first.status);
      expect(mapped.first.collectionId, mockData.items.first.collectionId);
      expect(mapped.first.invoiceId, mockData.items.first.invoiceId);
    });

    test('getRefund returns refund detail by id', () async {
      final mockData = await mockRepo.getRefund(
        query: kQuery,
        refundId: 'ref_4',
      );
      expect(mockData, isNotNull);
      expect(mockData!.collectionId, 'col_3');

      final mapped = const FinanceMapper().toRefundRequest(
        RefundRequestDto.fromJson(_fixtures.refundItem(mockData)),
      );
      expect(mapped.id, mockData.id);
      expect(mapped.invoiceId, mockData.invoiceId);
    });

    test('recovery contact backend envelope maps to domain', () {
      const mapper = FinanceMapper();
      final mapped = mapper.toRecoveryContact(
        RecoveryContactDto.fromJson(const {
          'id': 'rc_1',
          'studentId': 'stu_1',
          'channel': 'whatsapp',
          'outcome': 'no_answer',
          'notes': 'Reminder sent',
          'contactedBy': 'user_1',
          'timestamp': '2026-07-01T10:00:00Z',
        }),
      );
      expect(mapped.id, 'rc_1');
      expect(mapped.channel, 'whatsapp');
      expect(mapped.outcome, 'no_answer');
    });

    test('promise-to-pay backend envelope maps to domain', () {
      const mapper = FinanceMapper();
      final mapped = mapper.toPromiseToPay(
        PromiseToPayDto.fromJson(const {
          'id': 'ptp_1',
          'studentId': 'stu_1',
          'studentName': 'Priya Sharma',
          'amount': '650.00',
          'promiseDate': '2026-07-10',
          'status': 'pending',
          'notes': 'After salary',
          'createdAt': '2026-07-01T10:00:00Z',
          'resolvedAt': '',
        }),
      );
      expect(mapped.id, 'ptp_1');
      expect(mapped.status, PromiseToPayStatus.pending);
      expect(mapped.studentName, 'Priya Sharma');
    });

    test('recovery dashboard backend envelope maps to domain', () {
      const mapper = FinanceMapper();
      final mapped = mapper.toRecoveryDashboard(
        RecoveryDashboardDto.fromJson(const {
          'data': {
            'period': '2026-07',
            'ptpPending': 3,
            'ptpDueToday': 1,
            'ptpOverdue': 2,
            'ptpKept': 5,
            'ptpBroken': 1,
            'contactsThisMonth': 20,
            'recoveredThisMonth': '95000.00',
            'collectorPerformance': [
              {
                'collectorId': 'user_1',
                'collectorName': 'Finance Admin',
                'contactsMade': 12,
                'promisesObtained': 5,
                'collectionsCount': 3,
                'amountRecovered': '95000.00',
              },
            ],
          },
        }),
      );
      expect(mapped.period, '2026-07');
      expect(mapped.ptpPending, 3);
      expect(mapped.collectorPerformance.single.collectorName, 'Finance Admin');
    });

    test('mock recovery: log contact, PTP create/resolve, dashboard', () async {
      final contact = await mockRepo.logRecoveryContact(
        query: kQuery,
        request: const LogRecoveryContactRequest(
          studentId: 'def_1',
          channel: RecoveryChannel.call,
          outcome: RecoveryOutcome.promised,
          notes: 'Will pay Friday',
        ),
      );
      expect(contact.studentId, 'def_1');

      final contacts = await mockRepo.listRecoveryContacts(
        query: kQuery,
        studentId: 'def_1',
      );
      expect(contacts, isNotEmpty);

      final promise = await mockRepo.createPromiseToPay(
        query: kQuery,
        request: const CreatePromiseToPayRequest(
          studentId: 'def_1',
          amount: '65000',
          promiseDate: '2026-07-15',
        ),
      );
      expect(promise.status, PromiseToPayStatus.pending);

      final resolved = await mockRepo.resolvePromiseToPay(
        query: kQuery,
        promiseId: promise.id,
        request: const ResolvePromiseToPayRequest(
          status: PromiseToPayStatus.kept,
        ),
      );
      expect(resolved.status, PromiseToPayStatus.kept);

      final pending = await mockRepo.listPromisesToPay(
        query: kQuery,
        status: PromiseToPayStatus.pending,
      );
      expect(pending.any((p) => p.id == promise.id), isFalse);

      final dashboard = await mockRepo.getRecoveryDashboard(query: kQuery);
      expect(dashboard.collectorPerformance, isNotEmpty);
    });

    test('getInvoices DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getInvoices(query: kQuery);
      final mapped = const FinanceMapper().toInvoices(
        FinanceInvoicesResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final invoice in mockData.items)
              _fixtures.invoiceItem(invoice),
          ]),
        ),
      );

      expect(mapped.length, mockData.items.length);
      expect(mapped.first.invoiceNumber, mockData.items.first.invoiceNumber);
      expect(mapped.first.invoiceStatus, mockData.items.first.invoiceStatus);
    });

    test('getInvoice maps to installment history entry', () async {
      final mockData = await mockRepo.getInvoice(
        query: kQuery,
        invoiceId: 'inv_1',
      );
      expect(mockData, isNotNull);
      const mapper = FinanceMapper();
      final mapped = mapper.toFinanceInvoice(
        FinanceInvoiceDto.fromJson(_fixtures.invoiceItem(mockData!)),
      );
      final history = mapper.toInstallmentHistory(mapped);
      expect(history.termLabel, 'Annual');
      expect(history.amount, mapped.totalAmount);
    });

    // FIN-6 — invoice installment schedule round-trip.
    test('getInvoiceInstallments DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getInvoiceInstallments(
        query: kQuery,
        invoiceId: 'inv_1',
      );
      final mapped = const FinanceMapper().toInvoiceInstallments(
        InstallmentScheduleResponseDto.fromJson(
          _fixtures.installmentScheduleEnvelope(mockData),
        ),
      );
      expect(mapped.length, mockData.length);
      if (mockData.isNotEmpty) {
        expect(mapped.first.termNo, mockData.first.termNo);
        expect(mapped.first.amount, mockData.first.amount);
        expect(mapped.first.status, mockData.first.status);
      }
    });

    // FIN-9 — head-wise dues round-trip.
    test('getHeadWiseDues DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getHeadWiseDues(query: kQuery);
      final mapped = const FinanceMapper().toHeadWiseDues(
        HeadWiseDuesResponseDto.fromJson(
          _fixtures.headWiseDuesEnvelope(mockData),
        ),
      );
      expect(mapped.length, mockData.length);
      if (mockData.isNotEmpty) {
        expect(mapped.first.feeHead, mockData.first.feeHead);
        expect(mapped.first.label, mockData.first.label);
        expect(mapped.first.dues, mockData.first.dues);
      }
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
      expect((await mockRepo.getCollections(query: kQuery)).items, isNotEmpty);
      expect(
        (await mockRepo.listOfflinePayments(query: kQuery)).items,
        isNotEmpty,
      );
      final qrSession = await mockRepo.createQrPaymentSession(
        query: kQuery,
        request: const CreateQrPaymentSessionRequest(
          invoiceId: 'inv_1',
          amount: '4000',
        ),
      );
      expect(qrSession.status, QrPaymentSessionStatus.pending);
      expect(
        await mockRepo.getQrPaymentSession(
          query: kQuery,
          sessionId: qrSession.id,
        ),
        isNotNull,
      );
      expect(await mockRepo.getDailySummary(query: kQuery), isNotNull);
      expect(
        (await mockRepo.getFeeStructures(
          query: kQuery,
          academicYear: '2026-27',
        ))
            .items,
        isNotEmpty,
      );
      expect(
          (await mockRepo.getAcademicYears(query: kQuery)).items, isNotEmpty);
      expect(
          (await mockRepo.getStudentAccounts(query: kQuery)).items, isNotEmpty);
      expect((await mockRepo.getInstallmentPlans(query: kQuery)).items,
          isNotEmpty);
      expect(
        await mockRepo.getCollectionDetail(
          query: kQuery,
          collectionId: 'col_1',
        ),
        isNotNull,
      );
      expect(await mockRepo.getDefaultersDashboard(query: kQuery), isNotNull);
      expect(
          (await mockRepo.getRefundRequests(query: kQuery)).items, isNotEmpty);
      expect(await mockRepo.getDiscountsDashboard(query: kQuery), isNotNull);
      expect(await mockRepo.getReportsData(query: kQuery), isNotNull);
      expect(await mockRepo.getSettings(query: kQuery), isNotNull);
      expect(await mockRepo.getRecoveryDashboard(query: kQuery), isNotNull);
      expect(
        (await mockRepo.listPromisesToPay(query: kQuery)),
        isNotEmpty,
      );
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
            for (final payment in mockCollections.items)
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
      expect(collections.items.length, mockCollections.items.length);
      expect(collections.items.first.id, mockCollections.items.first.id);
    });
  });
}
