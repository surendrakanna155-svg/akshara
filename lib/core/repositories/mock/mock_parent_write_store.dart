import '../../../features/parent/leave/leave_models.dart';
import '../../../features/parent/parent_requests.dart';

/// Mutable in-memory store backing mock parent write operations.
class MockParentWriteStore {
  MockParentWriteStore._();

  static final MockParentWriteStore instance = MockParentWriteStore._();

  List<LeaveRequest>? leaveRequests;
  final Map<String, ParentPaymentInitiateRequest> paymentIntents = {};

  int _leaveSeq = 100;
  int _intentSeq = 500;

  String nextLeaveId() => 'lv_${++_leaveSeq}';
  String nextPaymentIntentId() => 'pi_${++_intentSeq}';
}
