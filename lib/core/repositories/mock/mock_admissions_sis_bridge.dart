import '../../../features/admissions/admissions_models.dart';
import '../../../features/finance/finance_models.dart';
import '../../../features/sis/sis_models.dart';
import 'mock_admissions_write_store.dart';
import 'mock_sis_write_store.dart';

/// Links mock admissions write paths to the SIS conversion queue for E2E journeys.
abstract final class MockAdmissionsSisBridge {
  static void syncEnrollmentToConversionQueue(PendingEnrollmentRecord enrollment) {
    final sisStore = MockSisWriteStore.instance;
    sisStore.conversionQueue ??= [];
    sisStore.conversionQueue!.removeWhere(
      (item) => item.enrollment.id == enrollment.id,
    );
    sisStore.conversionQueue!.insert(
      0,
      SisEnrollmentQueueItem(
        enrollment: enrollment,
        effectiveStatus: enrollment.conversionStatus,
      ),
    );
  }

  static bool isApplicationApproved(String applicationId) {
    final queue = MockAdmissionsWriteStore.instance.approvalQueue;
    if (queue == null) return false;
    return queue.any(
      (item) =>
          item.applicationId == applicationId &&
          item.decision == ApprovalDecision.approved,
    );
  }

  static PendingEnrollmentRecord? findEnrollment(String enrollmentId) {
    return MockAdmissionsWriteStore.instance.findEnrollment(enrollmentId);
  }

  /// Persists finance fee assignment and queues SIS conversion when applicable.
  static void completeFinanceHandoff({
    required String handoffId,
    required GeneratedFeeAccountPreview preview,
  }) {
    final admissionsStore = MockAdmissionsWriteStore.instance;
    final handoffs = admissionsStore.handoffs;
    if (handoffs != null) {
      final index = handoffs.indexWhere((item) => item.id == handoffId);
      if (index >= 0) {
        final current = handoffs[index];
        handoffs[index] = ApprovedStudentHandoff(
          id: current.id,
          studentName: current.studentName,
          classLabel: current.classLabel,
          applicationId: current.applicationId,
          admissionNumber: preview.admissionNumber,
          needsTransport: current.needsTransport,
          needsHostel: current.needsHostel,
          selectedFeeStructureId: current.selectedFeeStructureId,
          handoffStatus: FeeHandoffStatus.completed,
          previewStudentId: current.previewStudentId,
          sisHandoffLabel: 'Fee account ${preview.accountId} linked',
        );
      }
    }

    final enrollment = admissionsStore.enrollments?.cast<PendingEnrollmentRecord?>().firstWhere(
          (record) =>
              record?.generatedAdmissionNumber == preview.admissionNumber ||
              record?.studentName == preview.studentName,
          orElse: () => null,
        );
    if (enrollment != null) {
      syncEnrollmentToConversionQueue(enrollment);
    }
  }
}
