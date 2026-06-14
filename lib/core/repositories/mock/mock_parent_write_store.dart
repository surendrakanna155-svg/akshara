import '../../../features/parent/leave/leave_models.dart';
import '../../../features/parent/parent_requests.dart';
import '../../../features/teacher/messages/message_models.dart';

/// Mutable in-memory store backing mock parent write operations.
class MockParentWriteStore {
  MockParentWriteStore._();

  static final MockParentWriteStore instance = MockParentWriteStore._();

  List<LeaveRequest>? leaveRequests;
  List<MessageThread>? messageThreads;
  final Map<String, ParentPaymentInitiateRequest> paymentIntents = {};

  int _leaveSeq = 100;
  int _intentSeq = 500;
  int _threadSeq = 20;
  int _messageSeq = 200;

  String nextLeaveId() => 'lv_${++_leaveSeq}';
  String nextPaymentIntentId() => 'pi_${++_intentSeq}';
  String nextThreadId() => 'parent_thread_${++_threadSeq}';
  String nextMessageId() => 'parent_msg_${++_messageSeq}';
}
