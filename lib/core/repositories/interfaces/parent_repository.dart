import '../../../features/parent/academics/parent_academic_models.dart';
import '../../../features/parent/attendance/attendance_models.dart';
import '../../../features/parent/dashboard/parent_dashboard_provider.dart';
import '../../../features/parent/events/events_models.dart';
import '../../../features/parent/exams/exam_models.dart';
import '../../../features/parent/fees/fee_certificate_models.dart';
import '../../../features/parent/fees/fees_provider.dart';
import '../../../features/parent/homework/homework_models.dart';
import '../../../features/parent/leave/leave_models.dart';
import '../../../features/parent/notices/notices_models.dart';
import '../../../features/parent/parent_requests.dart';
import '../../../features/parent/payment/payment_models.dart';
import '../../../features/parent/profile/profile_models.dart';
import '../../../features/parent/receipts/receipt_models.dart';
import '../../../features/parent/timetable/timetable_models.dart';
import '../../../features/teacher/messages/message_models.dart';
import '../../communication/parent_communication_models.dart';
import '../repository_query.dart';

/// Contract for parent mobile app data access (mock or API).
abstract class ParentRepository {
  Future<ParentDashboardData> getDashboard({required RepositoryQuery query});
  Future<AttendanceMonthData> getAttendance({
    required RepositoryQuery query,
    required DateTime month,
  });
  Future<ParentHomeworkData> getHomework({required RepositoryQuery query});
  Future<ParentExamsData> getExams({required RepositoryQuery query});
  Future<ParentTimetableData> getTimetable({required RepositoryQuery query});
  Future<ParentFeesData> getFees({required RepositoryQuery query});
  Future<List<FeeReceipt>> getReceipts({required RepositoryQuery query});

  /// PAR-D3 — the active child's annual (Section 80C) fee-payment certificate
  /// for [academicYear] (`YYYY-YYYY`; the server falls back to the current FY
  /// when null/garbage). Own-child scoped server-side. Wired to
  /// `GET /parent/fee-certificate?academicYear=YYYY-YYYY`.
  Future<FeeCertificateData> getFeeCertificate({
    required RepositoryQuery query,
    String? academicYear,
  });
  Future<List<ParentNotice>> getNotices({required RepositoryQuery query});
  Future<ParentEventsData> getEvents({required RepositoryQuery query});
  Future<List<LeaveRequest>> getLeaveHistory({required RepositoryQuery query});
  Future<ParentProfileData> getProfile({
    required RepositoryQuery query,
    required String activeChildId,
  });
  Future<PaymentSummary> getPaymentSummary({
    required RepositoryQuery query,
    required String installmentId,
  });

  Future<LeaveRequest> submitLeaveRequest({
    required RepositoryQuery query,
    required ParentLeaveSubmitRequest request,
  });

  /// PAR-D1 — cancel/withdraw a PENDING leave the parent submitted for their OWN
  /// child. Own-child + pending-only guards are enforced server-side; an
  /// already-decided leave surfaces a 409 (LEAVE_NOT_PENDING) the caller shows
  /// as "already decided". Wired to `POST /parent/leave/:id/cancel`.
  Future<ParentLeaveCancelResult> cancelLeaveRequest({
    required RepositoryQuery query,
    required String leaveId,
  });

  /// PAR-3 — attach a medical-certificate reference (file name + optional
  /// storage path) to a PENDING own-child leave. Follows the HWK-7 attachment-
  /// reference pattern (a reference/label; real upload pending storage). Wired
  /// to `POST /parent/leave/:id/attachment`.
  Future<ParentLeaveAttachmentResult> attachLeaveDocument({
    required RepositoryQuery query,
    required String leaveId,
    required String fileName,
    String? storagePath,
  });

  Future<PaymentInitiationResult> initiatePayment({
    required RepositoryQuery query,
    required ParentPaymentInitiateRequest request,
  });

  Future<PaymentConfirmationResult> confirmPayment({
    required RepositoryQuery query,
    required ParentPaymentConfirmRequest request,
  });

  Future<ParentAcademicSummary> getAcademicSummary({
    required RepositoryQuery query,
    required String studentId,
  });

  Future<String> getPrintableReport({
    required RepositoryQuery query,
    required String studentId,
  });

  Future<List<MessageThread>> getMessageThreads({required RepositoryQuery query});

  Future<MessageThread> sendMessage({
    required RepositoryQuery query,
    required ParentMessageSendRequest request,
  });

  Future<List<ParentCommunicationInboxItem>> getCommunicationInbox({
    required RepositoryQuery query,
    required String activeChildId,
  });

  Future<ParentCommunicationInboxItem?> getCommunicationMessage({
    required RepositoryQuery query,
    required String communicationId,
  });

  Future<void> markCommunicationRead({
    required RepositoryQuery query,
    required String communicationId,
  });

  Future<void> acknowledgeCommunication({
    required RepositoryQuery query,
    required String communicationId,
  });
}
