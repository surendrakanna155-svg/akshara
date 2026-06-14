import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_admissions_write_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/admissions/admissions_requests.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/finance_requests.dart';
import 'package:flutter_test/flutter_test.dart';

/// Admission approve → finance handoff → fee account assignment chain.
void main() {
  group('Admission → Finance E2E (mock repositories)', () {
    const query = RepositoryQuery.demo;
    late MockAdmissionsRepository admissions;
    late MockFinanceRepository finance;

    setUp(() {
      admissions = MockAdmissionsRepository();
      finance = MockFinanceRepository();
      final store = MockAdmissionsWriteStore.instance;
      store.leads = null;
      store.applications = null;
      store.enrollments = null;
      store.approvalQueue = null;
      store.handoffs = null;
      store.applicationLeadIds.clear();
    });

    test('approved enrollment creates handoff and fee account', () async {
      const studentName = 'Finance Chain Student';
      const parentName = 'Finance Chain Parent';

      final lead = await admissions.createLead(
        query: query,
        request: const CreateLeadRequest(
          parentName: parentName,
          studentName: studentName,
          classLabel: '5',
          phone: '9876500002',
        ),
      );

      final app = await admissions.createApplication(
        query: query,
        request: CreateApplicationRequest(
          studentName: studentName,
          classLabel: '5',
          parentName: parentName,
          leadId: lead.id,
        ),
      );

      await admissions.submitApplication(query: query, applicationId: app.id);

      await admissions.submitEnrollment(
        query: query,
        request: EnrollmentSubmitRequest(
          student: const EnrollmentStudentProfile(fullName: studentName),
          parent: const EnrollmentParentInfo(
            guardianName: parentName,
            relationship: 'Father',
            phone: '9876500002',
          ),
          academic: const EnrollmentAcademicInfo(
            seekingClass: '5',
            section: 'A',
            academicYear: '2026–27',
          ),
          applicationId: app.id,
        ),
      );

      final approval = MockAdmissionsWriteStore.instance.findApprovalByApplication(
        app.id,
      );
      expect(approval, isNotNull);

      await admissions.approveAdmission(
        query: query,
        approvalId: approval!.id,
        request: const ApprovalDecisionRequest(comment: 'Approved for finance E2E'),
      );

      final handoffs = await admissions.getApprovedHandoffs(query: query);
      final handoff = handoffs.items.cast<ApprovedStudentHandoff?>().firstWhere(
            (item) => item?.applicationId == app.id,
            orElse: () => null,
          );
      expect(handoff, isNotNull);
      expect(handoff!.studentName, studentName);
      expect(handoff.handoffStatus, FeeHandoffStatus.pending);

      final sent = await admissions.sendToFinance(
        query: query,
        request: FinanceHandoffRequest(
          handoffId: handoff.id,
          feeStructureId: 'fee_std',
        ),
      );
      expect(sent.handoffStatus, FeeHandoffStatus.sentToFinance);

      final accountsBefore = await finance.getStudentAccounts(query: query);
      final countBefore = accountsBefore.total;

      final account = await finance.assignFeePlan(
        query: query,
        request: AssignFeePlanRequest(
          handoffId: handoff.id,
          feeStructureId: 'fee_std',
          installmentPlanId: 'plan_quarterly',
          studentName: studentName,
          admissionNumber: handoff.admissionNumber,
          classLabel: handoff.classLabel,
        ),
      );
      expect(account.studentName, studentName);

      final accountsAfter = await finance.getStudentAccounts(query: query);
      expect(accountsAfter.total, greaterThan(countBefore));
      expect(
        accountsAfter.items.any((item) => item.admissionNumber == handoff.admissionNumber),
        isTrue,
      );

      final invoices = await finance.getInvoices(query: query);
      final invoice = invoices.items.cast<FinanceInvoice?>().firstWhere(
            (item) => item?.studentId == account.id,
            orElse: () => null,
          );
      expect(invoice, isNotNull);

      final collectionsBefore = await finance.getCollections(query: query);
      final collectionCountBefore = collectionsBefore.total;

      final collection = await finance.createCollection(
        query: query,
        request: CreateCollectionRequest(
          invoiceId: invoice!.id,
          amountCollected: '10000',
          paymentMethod: 'UPI',
          collectionDate: 'Today',
        ),
      );
      expect(collection.receiptNumber, isNotEmpty);

      final collectionsAfter = await finance.getCollections(query: query);
      expect(collectionsAfter.total, greaterThan(collectionCountBefore));
      expect(
        collectionsAfter.items.any(
          (payment) => payment.receiptNumber == collection.receiptNumber,
        ),
        isTrue,
      );
    });
  });
}
