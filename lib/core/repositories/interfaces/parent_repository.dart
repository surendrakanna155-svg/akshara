import '../../../features/parent/academics/parent_academic_models.dart';
import '../../../features/parent/attendance/attendance_models.dart';
import '../../../features/parent/dashboard/parent_dashboard_provider.dart';
import '../../../features/parent/events/events_models.dart';
import '../../../features/parent/exams/exam_models.dart';
import '../../../features/parent/fees/fees_provider.dart';
import '../../../features/parent/homework/homework_models.dart';
import '../../../features/parent/leave/leave_models.dart';
import '../../../features/parent/notices/notices_models.dart';
import '../../../features/parent/parent_requests.dart';
import '../../../features/parent/payment/payment_models.dart';
import '../../../features/parent/profile/profile_models.dart';
import '../../../features/parent/receipts/receipt_models.dart';
import '../../../features/parent/timetable/timetable_models.dart';
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
}
