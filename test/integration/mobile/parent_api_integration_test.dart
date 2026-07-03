import 'package:akshara_erp/core/repositories/api/parent/api_parent_repository.dart';
import 'package:akshara_erp/core/repositories/api/parent/remote/parent_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/parent/remote/parent_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_provider.dart';
import 'package:akshara_erp/features/parent/leave/leave_models.dart';
import 'package:akshara_erp/features/parent/parent_requests.dart';
import 'package:akshara_erp/features/parent/payment/payment_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/mobile/parent_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = ParentFixtureBuilder();

void main() {
  group('Parent API integration', () {
    late MockParentRepository mockRepo;
    late LeaveRequest submittedLeave;
    late PaymentInitiationResult paymentInitiation;
    late PaymentConfirmationResult paymentConfirmation;
    late Map<String, dynamic> Function(RequestOptions options) responseForRequest;

    setUp(() async {
      mockRepo = MockParentRepository();
      submittedLeave = await mockRepo.submitLeaveRequest(
        query: kQuery,
        request: const ParentLeaveSubmitRequest(
          childId: 'child_ravi',
          fromDateLabel: '12 Jun 2026',
          toDateLabel: '12 Jun 2026',
          reason: 'Doctor advised rest for one day.',
          type: LeaveType.sick,
        ),
      );
      paymentInitiation = await mockRepo.initiatePayment(
        query: kQuery,
        request: const ParentPaymentInitiateRequest(
          installmentId: 'term_2',
          paymentMethod: PaymentMethod.upi,
          amount: 4200,
        ),
      );
      paymentConfirmation = await mockRepo.confirmPayment(
        query: kQuery,
        request: ParentPaymentConfirmRequest(
          paymentIntentId: paymentInitiation.paymentIntentId,
          transactionRef: 'TXN-123',
        ),
      );
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final attendance = await mockRepo.getAttendance(
        query: kQuery,
        month: DateTime(2026, 6, 1),
      );
      final homework = await mockRepo.getHomework(query: kQuery);
      final exams = await mockRepo.getExams(query: kQuery);
      final timetable = await mockRepo.getTimetable(query: kQuery);
      final fees = await mockRepo.getFees(query: kQuery);
      final receipts = await mockRepo.getReceipts(query: kQuery);
      final notices = await mockRepo.getNotices(query: kQuery);
      final events = await mockRepo.getEvents(query: kQuery);
      final leave = await mockRepo.getLeaveHistory(query: kQuery);
      final profile = await mockRepo.getProfile(
        query: kQuery,
        activeChildId: 'child_ravi',
      );
      final payment = await mockRepo.getPaymentSummary(
        query: kQuery,
        installmentId: 'term_2',
      );

      responseForRequest = (options) {
        final path = options.path;
        if (options.method == 'POST') {
          return switch (path) {
            ParentApiPaths.leave =>
              _fixtures.envelope(_fixtures.leaveItem(submittedLeave)),
            ParentApiPaths.paymentsInitiate =>
              _fixtures.paymentInitiationEnvelope(paymentInitiation),
            ParentApiPaths.paymentsConfirm =>
              _fixtures.paymentConfirmationEnvelope(paymentConfirmation),
            // PAR-D1 / PAR-3 leave write endpoints.
            _ when path.endsWith('/cancel') =>
              _fixtures.envelope(<String, dynamic>{
                'id': submittedLeave.id,
                'status': 'cancelled',
              }),
            _ when path.endsWith('/attachment') =>
              _fixtures.envelope(<String, dynamic>{
                'id': submittedLeave.id,
                'hasAttachment': true,
                'attachmentName': 'medical_cert.pdf',
              }),
            _ => const {'data': {}},
          };
        }
        return switch (path) {
            ParentApiPaths.dashboard => _fixtures.dashboardEnvelope(dashboard),
            ParentApiPaths.attendance => _fixtures.attendanceEnvelope(attendance),
            ParentApiPaths.homework => _fixtures.homeworkEnvelope(homework),
            ParentApiPaths.exams => _fixtures.examsEnvelope(exams),
            ParentApiPaths.timetable => _fixtures.timetableEnvelope(timetable),
            ParentApiPaths.fees => _fixtures.feesEnvelope(fees),
            ParentApiPaths.receipts => _fixtures.listEnvelope([
                for (final receipt in receipts) _fixtures.receiptItem(receipt),
              ]),
            ParentApiPaths.notices => _fixtures.listEnvelope([
                for (final notice in notices) _fixtures.noticeItem(notice),
              ]),
            ParentApiPaths.events => _fixtures.eventsEnvelope(events),
            ParentApiPaths.leave => _fixtures.listEnvelope([
                for (final request in leave) _fixtures.leaveItem(request),
              ]),
            ParentApiPaths.profile => _fixtures.profileEnvelope(profile),
            _ when path.startsWith('${ParentApiPaths.base}/payments/') =>
              _fixtures.paymentSummaryEnvelope(payment),
            _ => const {'data': {}},
          };
      };
    });

    test('remote datasource fetches all Parent read endpoints', () async {
      final remote = ParentRemoteDataSource(
        createFakeDio(responseForRequest),
      );

      expect((await remote.fetchDashboard(query: kQuery)).raw['childName'], isNotNull);
      expect((await remote.fetchAttendance(
        query: kQuery,
        month: DateTime(2026, 6, 1),
      )).raw['kpi'], isNotNull);
      expect((await remote.fetchHomework(query: kQuery)).raw['items'], isNotNull);
      expect((await remote.fetchExams(query: kQuery)).raw['upcomingExams'], isNotNull);
      expect((await remote.fetchTimetable(query: kQuery)).raw['days'], isNotNull);
      expect((await remote.fetchFees(query: kQuery)).raw['pendingAmount'], isNotNull);
      expect((await remote.fetchReceipts(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchNotices(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchEvents(query: kQuery)).raw['upcomingEvents'], isNotNull);
      expect((await remote.fetchLeaveHistory(query: kQuery)).items, isNotEmpty);
      expect((await remote.fetchProfile(
        query: kQuery,
        activeChildId: 'child_ravi',
      )).raw['children'], isNotNull);
      expect((await remote.fetchPaymentSummary(
        query: kQuery,
        installmentId: 'term_2',
      )).raw['installmentId'], 'term_2');
    });

    test('remote datasource posts all Parent write endpoints', () async {
      final remote = ParentRemoteDataSource(createFakeDio(responseForRequest));

      final leave = await remote.submitLeaveRequest(
        query: kQuery,
        request: const ParentLeaveSubmitRequest(
          childId: 'child_ravi',
          fromDateLabel: '12 Jun 2026',
          toDateLabel: '12 Jun 2026',
          reason: 'Doctor advised rest for one day.',
        ),
      );
      expect(leave.raw['id'], submittedLeave.id);

      final initiation = await remote.initiatePayment(
        query: kQuery,
        request: const ParentPaymentInitiateRequest(
          installmentId: 'term_2',
          paymentMethod: PaymentMethod.upi,
          amount: 4200,
        ),
      );
      expect(initiation.raw['paymentIntentId'], paymentInitiation.paymentIntentId);

      final confirmation = await remote.confirmPayment(
        query: kQuery,
        request: ParentPaymentConfirmRequest(
          paymentIntentId: paymentInitiation.paymentIntentId,
          transactionRef: 'TXN-123',
        ),
      );
      expect(confirmation.raw['receiptId'], paymentConfirmation.receiptId);

      // PAR-D1 — cancel POSTs to /parent/leave/:id/cancel and returns {id,status}.
      final cancelled = await remote.cancelLeaveRequest(
        query: kQuery,
        leaveId: submittedLeave.id,
      );
      expect(cancelled['status'], 'cancelled');

      // PAR-3 — attach POSTs to /parent/leave/:id/attachment.
      final attached = await remote.attachLeaveDocument(
        query: kQuery,
        leaveId: submittedLeave.id,
        fileName: 'medical_cert.pdf',
      );
      expect(attached['hasAttachment'], true);
      expect(attached['attachmentName'], 'medical_cert.pdf');
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiParentRepository(
        remote: ParentRemoteDataSource(createFakeDio(responseForRequest)),
      );

      final mockData = await mockRepo.getDashboard(query: kQuery);
      final apiData = await repository.getDashboard(query: kQuery);

      expect(apiData.childName, mockData.childName);
      expect(apiData.quickActions.length, mockData.quickActions.length);
    });

    test('provider chain loads dashboard in api mode', () async {
      await initProviderTestPrefs();
      final container = createProviderTestContainer(
        apiParentDio: createFakeDio(responseForRequest),
        parentApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data = await container.read(parentDashboardFutureProvider.future);
      expect(data.childName, isNotEmpty);
    });
  });
}
