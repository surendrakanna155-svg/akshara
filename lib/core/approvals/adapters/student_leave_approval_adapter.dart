import '../../../features/parent/leave/leave_models.dart';
import '../../leave/student_leave_governance_store.dart';
import '../../repositories/repository_query.dart';
import '../approval_center_service.dart';
import '../approval_models.dart';
import '../approval_request_type.dart';
import '../approval_requests.dart';
import 'approval_type_adapter.dart';

/// Connects parent student leave to the unified approval center (M-D4).
class StudentLeaveApprovalAdapter implements ApprovalTypeAdapter {
  StudentLeaveApprovalAdapter({StudentLeaveGovernanceStore? store})
      : _store = store ?? StudentLeaveGovernanceStore.instance;

  final StudentLeaveGovernanceStore _store;

  static const entityType = 'student_leave';

  Future<ApprovalRequest> submitForApproval({
    required ApprovalCenterService service,
    required RepositoryQuery query,
    required String leaveId,
    required String requesterId,
    required String requesterName,
    required Map<String, Object?> payload,
    required String title,
    required String summary,
  }) {
    _store.clearRejectionComment(leaveId);
    return service.submitApprovalRequest(
      query: query,
      request: SubmitApprovalRequest(
        type: ApprovalRequestType.studentLeave,
        title: title,
        summary: summary,
        requesterId: requesterId,
        requesterName: requesterName,
        entityType: entityType,
        entityId: leaveId,
        payload: payload,
      ),
    );
  }

  @override
  void onApproved({
    required RepositoryQuery query,
    required ApprovalRequest request,
  }) {
    if (request.type != ApprovalRequestType.studentLeave) return;
    _store.applyDecision(
      leaveId: request.entityId,
      status: LeaveStatus.approved,
      comment: request.decisionComment ?? '',
    );
  }

  @override
  void onRejected({
    required RepositoryQuery query,
    required ApprovalRequest request,
    required String comment,
  }) {
    if (request.type != ApprovalRequestType.studentLeave) return;
    _store.applyDecision(
      leaveId: request.entityId,
      status: LeaveStatus.rejected,
      comment: comment,
    );
  }

  @override
  Map<String, String> enrichDetail(ApprovalRequest request) {
    if (request.type != ApprovalRequestType.studentLeave) return const {};
    final payload = request.payload;
    return {
      'Child': '${payload['childName'] ?? '—'}',
      'Class': '${payload['classLabel'] ?? '—'}',
      'From': '${payload['fromDate'] ?? '—'}',
      'To': '${payload['toDate'] ?? '—'}',
      'Type': '${payload['leaveType'] ?? '—'}',
      'Reason': '${payload['reason'] ?? request.summary}',
    };
  }
}
