import 'package:akshara_erp/core/repositories/mock/mock_admissions_sis_bridge.dart';
import 'package:akshara_erp/core/repositories/mock/mock_admissions_write_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_write_store.dart';
import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    final admissions = MockAdmissionsWriteStore.instance;
    admissions.leads = null;
    admissions.applications = null;
    admissions.enrollments = null;
    admissions.approvalQueue = null;
    admissions.handoffs = null;
    admissions.applicationLeadIds.clear();
    MockSisWriteStore.instance.students = null;
    MockSisWriteStore.instance.conversionQueue = null;
  });

  group('MockAdmissionsSisBridge.completeFinanceHandoff', () {
    test('updates handoff status to completed', () {
      final store = MockAdmissionsWriteStore.instance;
      store.handoffs = [
        const ApprovedStudentHandoff(
          id: 'ho_1',
          studentName: 'Test Student',
          classLabel: '9',
          applicationId: 'app_test_1',
          admissionNumber: 'ADM-TEST-001',
          needsTransport: false,
          needsHostel: false,
          selectedFeeStructureId: null,
          handoffStatus: FeeHandoffStatus.sentToFinance,
          previewStudentId: 'prev_1',
          sisHandoffLabel: '',
        ),
      ];

      const preview = GeneratedFeeAccountPreview(
        accountId: 'acct_test_1',
        studentName: 'Test Student',
        admissionNumber: 'ADM-TEST-001',
        feeStructureName: 'Annual Fee',
        totalDue: '₹60,000',
        installmentSummary: '3 instalments',
        addOns: [],
      );

      MockAdmissionsSisBridge.completeFinanceHandoff(
        handoffId: 'ho_1',
        preview: preview,
      );

      final updated = store.handoffs!.first;
      expect(updated.handoffStatus, FeeHandoffStatus.completed);
      expect(updated.sisHandoffLabel, contains('acct_test_1'));
    });

    test('queues SIS conversion when matching enrollment exists', () {
      final store = MockAdmissionsWriteStore.instance;
      store.enrollments = [
        const PendingEnrollmentRecord(
          id: 'enr_1',
          studentName: 'Journey Student',
          seekingClass: '6',
          section: 'A',
          applicationId: 'app_j1',
          guardianName: 'Journey Parent',
          phone: '9999999901',
          conversionStatus: EnrollmentConversionStatus.pending,
          academicYear: '2026–27',
          generatedAdmissionNumber: 'ADM-JOURNEY-001',
          submittedAt: '10 Jun 2026',
        ),
      ];

      const preview = GeneratedFeeAccountPreview(
        accountId: 'acct_j1',
        studentName: 'Journey Student',
        admissionNumber: 'ADM-JOURNEY-001',
        feeStructureName: 'Annual Fee',
        totalDue: '₹70,000',
        installmentSummary: '2 instalments',
        addOns: [],
      );

      MockAdmissionsSisBridge.completeFinanceHandoff(
        handoffId: 'ho_nonexistent',
        preview: preview,
      );

      final queue = MockSisWriteStore.instance.conversionQueue;
      expect(queue, isNotNull);
      expect(queue!.isNotEmpty, isTrue);
      expect(queue.first.enrollment.id, 'enr_1');
    });
  });
}
