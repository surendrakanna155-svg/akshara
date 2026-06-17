import '../../../features/parent/leave/leave_models.dart';
import '../repositories/mock/mock_parent_write_store.dart';

/// Mock-side effects for student leave approval decisions (M-D4).
class StudentLeaveGovernanceStore {
  StudentLeaveGovernanceStore._();

  static final StudentLeaveGovernanceStore instance =
      StudentLeaveGovernanceStore._();

  final Map<String, String> _rejectionCommentsByLeaveId = {};

  String? rejectionCommentFor(String leaveId) =>
      _rejectionCommentsByLeaveId[leaveId];

  void clearRejectionComment(String leaveId) {
    _rejectionCommentsByLeaveId.remove(leaveId);
  }

  void applyDecision({
    required String leaveId,
    required LeaveStatus status,
    required String comment,
  }) {
    final store = MockParentWriteStore.instance;
    final requests = store.leaveRequests;
    if (requests == null) return;

    final index = requests.indexWhere((l) => l.id == leaveId);
    if (index < 0) return;

    final current = requests[index];
    if (status == LeaveStatus.rejected && comment.isNotEmpty) {
      _rejectionCommentsByLeaveId[leaveId] = comment;
    } else {
      _rejectionCommentsByLeaveId.remove(leaveId);
    }

    final timeline = _timelineFor(status, comment);
    requests[index] = LeaveRequest(
      id: current.id,
      childName: current.childName,
      childClass: current.childClass,
      fromDateLabel: current.fromDateLabel,
      toDateLabel: current.toDateLabel,
      reason: current.reason,
      type: current.type,
      status: status,
      submittedLabel: current.submittedLabel,
      timeline: timeline,
      hasAttachment: current.hasAttachment,
      attachmentName: current.attachmentName,
    );
  }

  List<LeaveTimelineStep> _timelineFor(LeaveStatus status, String comment) {
    return switch (status) {
      LeaveStatus.approved => const [
          LeaveTimelineStep(
            label: 'Submitted',
            dateLabel: 'Complete',
            isComplete: true,
          ),
          LeaveTimelineStep(
            label: 'Principal approval',
            dateLabel: 'Approved',
            isComplete: true,
          ),
        ],
      LeaveStatus.rejected => [
          const LeaveTimelineStep(
            label: 'Submitted',
            dateLabel: 'Complete',
            isComplete: true,
          ),
          LeaveTimelineStep(
            label: 'Principal decision',
            dateLabel: 'Rejected',
            isComplete: true,
            note: comment.isEmpty ? null : comment,
          ),
        ],
      _ => const [
          LeaveTimelineStep(
            label: 'Submitted',
            dateLabel: 'Complete',
            isComplete: true,
          ),
          LeaveTimelineStep(
            label: 'Principal review',
            dateLabel: 'Pending',
            isComplete: false,
          ),
        ],
    };
  }

  void reset() {
    _rejectionCommentsByLeaveId.clear();
  }
}
