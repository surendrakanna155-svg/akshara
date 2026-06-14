import '../../../features/admissions/admissions_models.dart';
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
}
