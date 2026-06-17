import '../../../features/hr/hr_models.dart';
import '../repositories/mock/mock_hr_write_store.dart';

/// Mock-side effects for staff leave approval decisions (M-D4).
class StaffLeaveGovernanceStore {
  StaffLeaveGovernanceStore._();

  static final StaffLeaveGovernanceStore instance = StaffLeaveGovernanceStore._();

  final Map<String, String> _rejectionCommentsByLeaveId = {};

  String? rejectionCommentFor(String leaveId) =>
      _rejectionCommentsByLeaveId[leaveId];

  void applyDecision({
    required String leaveId,
    required HrLeaveStatus status,
    required String comment,
    String approverName = 'Principal',
  }) {
    final store = MockHrWriteStore.instance;
    final requests = store.leaveRequests;
    if (requests == null) return;

    final index = requests.indexWhere((l) => l.id == leaveId);
    if (index < 0) return;

    final current = requests[index];
    if (status == HrLeaveStatus.rejected && comment.isNotEmpty) {
      _rejectionCommentsByLeaveId[leaveId] = comment;
    } else {
      _rejectionCommentsByLeaveId.remove(leaveId);
    }

    final note = comment.trim();
    final nextReason = note.isEmpty
        ? current.reason
        : '${current.reason}\nPrincipal note: $note';

    requests[index] = HrLeaveRequest(
      id: current.id,
      employeeId: current.employeeId,
      employeeName: current.employeeName,
      department: current.department,
      leaveType: current.leaveType,
      fromDate: current.fromDate,
      toDate: current.toDate,
      days: current.days,
      status: status,
      approver: approverName,
      reason: nextReason,
    );
  }

  void reset() {
    _rejectionCommentsByLeaveId.clear();
  }
}
