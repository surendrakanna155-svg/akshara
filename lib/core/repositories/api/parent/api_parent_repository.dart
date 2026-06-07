import '../../../../features/parent/attendance/attendance_models.dart';
import '../../../../features/parent/dashboard/parent_dashboard_provider.dart';
import '../../../../features/parent/events/events_models.dart';
import '../../../../features/parent/exams/exam_models.dart';
import '../../../../features/parent/fees/fees_provider.dart';
import '../../../../features/parent/homework/homework_models.dart';
import '../../../../features/parent/leave/leave_models.dart';
import '../../../../features/parent/notices/notices_models.dart';
import '../../../../features/parent/payment/payment_models.dart';
import '../../../../features/parent/profile/profile_models.dart';
import '../../../../features/parent/receipts/receipt_models.dart';
import '../../../../features/parent/timetable/timetable_models.dart';
import '../../interfaces/parent_repository.dart';
import '../../repository_query.dart';
import '../api_exception.dart';

/// API implementation of [ParentRepository] — enabled via [parentApiEnabledProvider].
class ApiParentRepository implements ParentRepository {
  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApiParentRepository', method);
  }

  @override
  Future<ParentDashboardData> getDashboard({required RepositoryQuery query}) async =>
      _notConnected('getDashboard');

  @override
  Future<AttendanceMonthData> getAttendance({
    required RepositoryQuery query,
    required DateTime month,
  }) async =>
      _notConnected('getAttendance');

  @override
  Future<ParentHomeworkData> getHomework({required RepositoryQuery query}) async =>
      _notConnected('getHomework');

  @override
  Future<ParentExamsData> getExams({required RepositoryQuery query}) async =>
      _notConnected('getExams');

  @override
  Future<ParentTimetableData> getTimetable({required RepositoryQuery query}) async =>
      _notConnected('getTimetable');

  @override
  Future<ParentFeesData> getFees({required RepositoryQuery query}) async =>
      _notConnected('getFees');

  @override
  Future<List<FeeReceipt>> getReceipts({required RepositoryQuery query}) async =>
      _notConnected('getReceipts');

  @override
  Future<List<ParentNotice>> getNotices({required RepositoryQuery query}) async =>
      _notConnected('getNotices');

  @override
  Future<ParentEventsData> getEvents({required RepositoryQuery query}) async =>
      _notConnected('getEvents');

  @override
  Future<List<LeaveRequest>> getLeaveHistory({required RepositoryQuery query}) async =>
      _notConnected('getLeaveHistory');

  @override
  Future<ParentProfileData> getProfile({
    required RepositoryQuery query,
    required String activeChildId,
  }) async =>
      _notConnected('getProfile');

  @override
  Future<PaymentSummary> getPaymentSummary({
    required RepositoryQuery query,
    required String installmentId,
  }) async =>
      _notConnected('getPaymentSummary');
}
