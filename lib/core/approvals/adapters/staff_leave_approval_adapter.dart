import '../../../features/hr/hr_models.dart';
import '../../leave/staff_leave_governance_store.dart';
import '../../repositories/repository_query.dart';
import '../approval_center_service.dart';
import '../approval_models.dart';
import '../approval_request_type.dart';
import '../approval_requests.dart';
import 'approval_type_adapter.dart';

/// Connects HR staff leave to the unified approval center (M-D4).
class StaffLeaveApprovalAdapter implements ApprovalTypeAdapter {
  StaffLeaveApprovalAdapter({StaffLeaveGovernanceStore? store})
      : _store = store ?? StaffLeaveGovernanceStore.instance;

  final StaffLeaveGovernanceStore _store;

  static const entityType = 'staff_leave';

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
    return service.submitApprovalRequest(
      query: query,
      request: SubmitApprovalRequest(
        type: ApprovalRequestType.staffLeave,
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
    if (request.type != ApprovalRequestType.staffLeave) return;
    _store.applyDecision(
      leaveId: request.entityId,
      status: HrLeaveStatus.approved,
      comment: request.decisionComment ?? '',
      approverName: request.decidedByName ?? 'Principal',
    );
  }

  @override
  void onRejected({
    required RepositoryQuery query,
    required ApprovalRequest request,
    required String comment,
  }) {
    if (request.type != ApprovalRequestType.staffLeave) return;
    _store.applyDecision(
      leaveId: request.entityId,
      status: HrLeaveStatus.rejected,
      comment: comment,
      approverName: request.decidedByName ?? 'Principal',
    );
  }

  @override
  Map<String, String> enrichDetail(ApprovalRequest request) {
    if (request.type != ApprovalRequestType.staffLeave) return const {};
    final payload = request.payload;
    return {
      'Employee': '${payload['employeeName'] ?? '—'}',
      'Department': '${payload['department'] ?? '—'}',
      'Type': '${payload['leaveType'] ?? '—'}',
      'From': '${payload['fromDate'] ?? '—'}',
      'To': '${payload['toDate'] ?? '—'}',
      'Days': '${payload['days'] ?? '—'}',
    };
  }
}
